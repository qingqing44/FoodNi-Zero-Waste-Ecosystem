import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';

import 'local_image_service.dart';

/// Prompt given to Gemini for freshness assessment.
const _kGeminiPrompt = '''
You are an expert food quality inspector.

Analyze the food image and return ONLY valid JSON.

{
  "foodName": "",
  "detectedItems": [
    {
      "name": "",
      "confidence": 0
    }
  ],
  "description": "",
  "category": "",
  "freshnessScore": 0,
  "freshnessStatus": "",
  "estimatedDaysRemaining": 0,
  "storageSuggestion": "",
  "caloriesPer100g": "",
  "basicRecipes": [
    {
      "title": "",
      "steps": ["", ""]
    }
  ],
  "confidence": 0,
  "reasoning": ""
}

Determine freshness using:
- color
- texture
- bruising
- mold
- dryness
- visible spoilage

Freshness Status:
- Fresh (80-100)
- Good (60-79)
- Consume Soon (40-59)
- Spoiled (0-39)

Rules:
- Base assessment only on visible appearance.
- If multiple foods are present, set "foodName" to the primary item and list
  the visible food items in "detectedItems" with individual confidence scores.
- "detectedItems" must include 1 to 5 food items that are visibly present.
- "description" should be a short, user-friendly summary of the food.
- "storageSuggestion" should be a short, specific storage method for this food.
- "caloriesPer100g" should be a concise value such as "52 kcal".
- "basicRecipes" must contain exactly 2 simple recipe objects using this food.
- Each recipe object must have a short "title" and 2 to 3 concise "steps".
- Return valid JSON only.
- No markdown.
- No explanations outside JSON.
''';

/// Orchestrates picking an image, saving it locally, and analysing it with Gemini.
///
/// No Firebase Storage is used; images live in the device's app documents dir.
class CameraService {
  static const Duration _geminiTimeout = Duration(seconds: 25);

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalImageService _localImageService = LocalImageService();

  /// Opens the device camera or gallery, saves the captured image locally,
  /// runs Gemini vision analysis, and returns a result map ready to be shown
  /// on the [FoodDetailsScreen].
  ///
  /// Returns `null` when the user cancels without selecting a photo.
  /// Throws a descriptive [Exception] on any real failure.
  Future<Map<String, dynamic>?> scanFoodItem({
    ImageSource source = ImageSource.camera,
  }) async {
    // 1. Pick image from camera or gallery.
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null; // User cancelled

    // 2. Require an authenticated user.
    final user = _auth.currentUser;
    if (user == null) throw Exception('You must be logged in to scan items.');

    // 3. Read bytes once, then store them in a platform-appropriate way.
    Uint8List imageBytes;
    try {
      imageBytes = await picked.readAsBytes();
    } catch (_) {
      throw const FoodScanException.invalidImage();
    }
    if (imageBytes.isEmpty) {
      throw const FoodScanException.invalidImage();
    }
    final ({String imagePath, String thumbnailPath}) storedImage;
    if (kIsWeb) {
      storedImage = await _localImageService.saveWebImage(imageBytes);
    } else {
      final imageFile = File(picked.path);
      storedImage = await _localImageService.saveImage(imageFile);
    }

    // 5. Analyse with Gemini.
    final analysisResult = await _analyseWithGemini(imageBytes);
    final foodName =
        analysisResult['foodName']?.toString().trim().isNotEmpty == true
        ? analysisResult['foodName'].toString().trim()
        : 'Unknown Food';
    final category =
        analysisResult['category']?.toString().trim().isNotEmpty == true
        ? analysisResult['category'].toString().trim()
        : 'Other';
    final freshnessStatus =
        analysisResult['freshnessStatus']?.toString().trim().isNotEmpty == true
        ? analysisResult['freshnessStatus'].toString().trim()
        : 'Unknown';
    final confidence = _normaliseConfidence(
      analysisResult['confidence'],
      foodName: foodName,
      category: category,
      freshnessStatus: freshnessStatus,
    );

    // 6. Return combined result (no Firebase Storage URL).
    return {
      'userId': user.uid,
      'localImagePath': storedImage.imagePath,
      'thumbnailPath': storedImage.thumbnailPath,
      'foodName': foodName,
      'detectedItems': _normaliseDetectedItems(
        analysisResult['detectedItems'],
        fallbackFoodName: foodName,
        fallbackConfidence: confidence,
      ),
      'description':
          analysisResult['description'] ??
          'No food description available.',
      'category': category,
      'freshnessScore': analysisResult['freshnessScore'] ?? 0,
      'freshnessStatus': freshnessStatus,
      'estimatedDaysRemaining': analysisResult['estimatedDaysRemaining'] ?? 0,
      'storageSuggestion':
          analysisResult['storageSuggestion'] ??
          'Store according to the recommended conditions for this food.',
      'caloriesPer100g':
          analysisResult['caloriesPer100g'] ?? 'Not available',
      'basicRecipes': _normaliseRecipes(analysisResult['basicRecipes']),
      'confidence': confidence,
      'reasoning': analysisResult['reasoning'] ?? 'No reasoning provided.',
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Sends [imageBytes] to the Gemini vision model and returns parsed JSON.
  /// Uses firebase_ai to securely communicate with Gemini using Firebase config.
  Future<Map<String, dynamic>> _analyseWithGemini(Uint8List imageBytes) async {
    const candidateModels = [
      'gemini-3.5-flash',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
    ];

    GenerateContentResponse? response;
    String? lastError;

    for (final modelName in candidateModels) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );

        response = await model.generateContent([
          Content.multi([
            InlineDataPart('image/jpeg', imageBytes),
            TextPart(_kGeminiPrompt),
          ]),
        ]).timeout(_geminiTimeout);
        break; // Success
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }

    if (response == null) {
      if (_isLikelyInvalidImageError(lastError)) {
        throw const FoodScanException.invalidImage();
      }
      throw const FoodScanException.unavailable();
    }

    final rawText = response.text;
    if (rawText == null || rawText.trim().isEmpty) {
      throw const FoodScanException.emptyResponse();
    }

    return _parseJson(rawText);
  }

  /// Safely parses a JSON string from Gemini, stripping markdown fences if present.
  Map<String, dynamic> _parseJson(String rawText) {
    // First attempt: parse directly.
    try {
      return jsonDecode(rawText) as Map<String, dynamic>;
    } catch (_) {
      // Second attempt: strip markdown code fences then retry.
      final cleaned = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      try {
        return jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (e) {
        throw const FoodScanException.unavailable();
      }
    }
  }

  List<Map<String, dynamic>> _normaliseDetectedItems(
    dynamic rawItems, {
    required String fallbackFoodName,
    required int fallbackConfidence,
  }) {
    if (rawItems is List) {
      final items = rawItems
          .map((item) {
            if (item is! Map) return null;
            final name = item['name']?.toString().trim() ?? '';
            if (name.isEmpty) return null;
            return {
              'name': name,
              'confidence': _parsePercentage(item['confidence']) ?? 0,
            };
          })
          .whereType<Map<String, dynamic>>()
          .take(5)
          .toList();
      if (items.isNotEmpty) return items;
    }

    return [
      {
        'name': fallbackFoodName,
        'confidence': fallbackConfidence,
      },
    ];
  }

  List<Map<String, dynamic>> _normaliseRecipes(dynamic rawRecipes) {
    if (rawRecipes is List) {
      final recipes = rawRecipes
          .map(_recipeMapFrom)
          .where((recipe) => recipe != null)
          .cast<Map<String, dynamic>>()
          .take(2)
          .toList();
      if (recipes.isNotEmpty) return _ensureTwoRecipes(recipes);
    }

    if (rawRecipes is String && rawRecipes.trim().isNotEmpty) {
      return _ensureTwoRecipes([
        {
          'title': 'Simple Serving Idea',
          'steps': [rawRecipes.trim()],
        },
      ]);
    }

    return _fallbackRecipes;
  }

  Map<String, dynamic>? _recipeMapFrom(dynamic rawRecipe) {
    if (rawRecipe is Map) {
      final title = rawRecipe['title']?.toString().trim() ?? '';
      final rawSteps = rawRecipe['steps'];
      final steps = rawSteps is List
          ? rawSteps
              .map((step) => step?.toString().trim() ?? '')
              .where((step) => step.isNotEmpty)
              .take(3)
              .toList()
          : <String>[];

      if (title.isEmpty && steps.isEmpty) return null;

      return {
        'title': title.isNotEmpty ? title : 'Recipe Idea',
        'steps': steps.isNotEmpty ? steps : ['No steps provided yet.'],
      };
    }

    final recipeText = rawRecipe?.toString().trim() ?? '';
    if (recipeText.isEmpty) return null;
    return {
      'title': 'Recipe Idea',
      'steps': [recipeText],
    };
  }

  List<Map<String, dynamic>> _ensureTwoRecipes(
    List<Map<String, dynamic>> recipes,
  ) {
    final result = List<Map<String, dynamic>>.from(recipes);
    while (result.length < 2) {
      result.add(_fallbackRecipes[result.length]);
    }
    return result.take(2).toList();
  }

  static const List<Map<String, dynamic>> _fallbackRecipes = [
    {
      'title': 'Fresh Snack Bowl',
      'steps': [
        'Slice the food into bite-sized pieces.',
        'Serve immediately as a simple fresh snack.',
      ],
    },
    {
      'title': 'Quick Kitchen Mix',
      'steps': [
        'Combine the food with a few pantry staples.',
        'Adjust seasoning and serve right away.',
      ],
    },
  ];

  int _normaliseConfidence(
    dynamic rawConfidence, {
    required String foodName,
    required String category,
    required String freshnessStatus,
  }) {
    final parsed = _parsePercentage(rawConfidence);
    if (parsed != null && parsed > 0) {
      return parsed;
    }

    // Gemini sometimes correctly identifies the food but leaves confidence at
    // 0 or returns a non-numeric value. In that case, provide a sensible
    // fallback instead of surfacing a misleading 0%.
    final hasRecognitionData =
        foodName != 'Unknown Food' ||
        category != 'Other' ||
        freshnessStatus != 'Unknown';

    return hasRecognitionData ? 85 : 0;
  }

  int? _parsePercentage(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.clamp(0, 100).round();
    }

    if (rawValue is String) {
      final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(rawValue);
      if (match != null) {
        final parsed = double.tryParse(match.group(0)!);
        if (parsed != null) {
          return parsed.clamp(0, 100).round();
        }
      }
    }

    return null;
  }

  bool _isLikelyInvalidImageError(String? error) {
    final value = (error ?? '').toLowerCase();
    return value.contains('unsupported') ||
        value.contains('invalid image') ||
        value.contains('corrupt') ||
        value.contains('decode') ||
        value.contains('format');
  }
}

class FoodScanException implements Exception {
  const FoodScanException._(this.userMessage);

  const FoodScanException.unavailable()
    : this._(
        'Unable to identify food at the moment. Please check your internet connection and try again.',
      );

  const FoodScanException.emptyResponse()
    : this._('No response was received from the AI. Please try again.');

  const FoodScanException.invalidImage()
    : this._('Unable to process image. Please upload a valid food image.');

  final String userMessage;

  @override
  String toString() => userMessage;
}
