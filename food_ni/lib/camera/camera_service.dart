import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';

import 'local_image_service.dart';

/// Prompt given to Gemini for freshness assessment.
const _kGeminiPrompt = '''
You are an expert food quality inspector.

Analyze the food image and return ONLY valid JSON.

{
  "foodName": "",
  "category": "",
  "freshnessScore": 0,
  "freshnessStatus": "",
  "estimatedDaysRemaining": 0,
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
- If multiple foods are present, choose the primary food item.
- Return valid JSON only.
- No markdown.
- No explanations outside JSON.
''';

/// Orchestrates picking an image, saving it locally, and analysing it with Gemini.
///
/// No Firebase Storage is used; images live in the device's app documents dir.
class CameraService {
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

    // 3. Save full image + thumbnail to permanent local storage.
    final imageFile = File(picked.path);
    final (:imagePath, :thumbnailPath) =
        await _localImageService.saveImage(imageFile);

    // 4. Read raw bytes for the Gemini vision request.
    final imageBytes = await File(imagePath).readAsBytes();

    // 5. Analyse with Gemini.
    final analysisResult = await _analyseWithGemini(imageBytes);

    // 6. Return combined result (no Firebase Storage URL).
    return {
      'userId': user.uid,
      'localImagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'foodName': analysisResult['foodName'] ?? 'Unknown Food',
      'category': analysisResult['category'] ?? 'Other',
      'freshnessScore': analysisResult['freshnessScore'] ?? 0,
      'freshnessStatus': analysisResult['freshnessStatus'] ?? 'Unknown',
      'estimatedDaysRemaining': analysisResult['estimatedDaysRemaining'] ?? 0,
      'confidence': analysisResult['confidence'] ?? 0,
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
        ]);
        break; // Success
      } catch (e) {
        lastError = e.toString();
        // If it's a server error (e.g. 500 high demand), we try the next model.
        // If it's something else we might still want to try the next model just in case.
        continue;
      }
    }

    if (response == null) {
      throw Exception('All Gemini models failed. Last error: $lastError');
    }

    final rawText = response.text;
    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('Gemini returned an empty response.');
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
        throw Exception('Could not parse AI response as JSON: $e\nRaw: $cleaned');
      }
    }
  }
}
