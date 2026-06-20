import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/food_item.dart';
import '../../models/recipe.dart';

/// Generates tailored recipes through the existing server-side AI proxy.
/// The mobile/web app never contains the model provider's API key.
class AiRecipeService {
  AiRecipeService({http.Client? client}) : _client = client ?? http.Client();

  static const _backendUrl =
      'https://foodni-chat-backend.vercel.app/api/chat';
  static const _timeout = Duration(seconds: 35);

  final http.Client _client;

  Future<List<Recipe>> generateRecipes(List<FoodItem> selectedItems) async {
    if (selectedItems.isEmpty) return [];

    final response = await _client
        .post(
          Uri.parse(_backendUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': [
              {
                'role': 'system',
                'content': _systemPrompt,
              },
              {
                'role': 'user',
                'content': _buildUserPrompt(selectedItems),
              },
            ],
          }),
        )
        .timeout(_timeout);

    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRecipeException(
        body['error']?.toString() ?? 'Could not generate recipes right now.',
      );
    }

    final rawRecipeJson = body['response']?.toString() ?? '';
    if (rawRecipeJson.trim().isEmpty) {
      throw const AiRecipeException('AI returned an empty recipe response.');
    }

    final recipePayload = _decodeRecipePayload(rawRecipeJson);
    final rawRecipes = recipePayload['recipes'];
    if (rawRecipes is! List) {
      throw const AiRecipeException('AI returned recipes in an invalid format.');
    }

    final recipes = <Recipe>[];
    for (var index = 0; index < rawRecipes.length && index < 5; index++) {
      final rawRecipe = rawRecipes[index];
      if (rawRecipe is! Map) continue;

      final data = Map<String, dynamic>.from(rawRecipe);
      final title = data['title']?.toString().trim() ?? '';
      final ingredients = _stringList(data['ingredients']);
      final instructions = _stringList(data['instructions']);
      if (title.isEmpty || ingredients.isEmpty || instructions.isEmpty) continue;

      recipes.add(
        Recipe(
          id: 'ai-${DateTime.now().microsecondsSinceEpoch}-$index',
          title: title,
          imageUrl: '',
          ingredients: ingredients,
          instructions: instructions,
          preparationTime: _toInt(data['preparationTime']),
          difficulty: data['difficulty']?.toString().trim().isNotEmpty == true
              ? data['difficulty'].toString().trim()
              : 'Easy',
          source: 'ai',
        ),
      );
    }

    if (recipes.isEmpty) {
      throw const AiRecipeException('AI could not create usable recipes. Try again.');
    }

    return recipes;
  }

  Map<String, dynamic> _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _decodeRecipePayload(String raw) {
    final cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const AiRecipeException('AI returned an invalid recipe response.');
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _buildUserPrompt(List<FoodItem> items) {
    final inventory = items.map((item) {
      final expiry = item.estimatedDaysRemaining == null
          ? ''
          : ', about ${item.estimatedDaysRemaining} days remaining';
      return '- ${item.name}$expiry';
    }).join('\n');

    return '''
Generate recipes using these selected FoodNi inventory items:
$inventory

Prioritize ingredients with fewer days remaining. Use common pantry staples such
as oil, salt, water, rice, flour, and basic seasonings only when necessary.
Create a fresh, distinct set of ideas for generation ${DateTime.now().microsecondsSinceEpoch}.
Avoid reusing obvious recipe titles or near-identical recipe concepts.
''';
  }

  static const _systemPrompt = '''
You are FoodNi's recipe generator. Create exactly five practical, beginner-friendly
recipes that reduce food waste by prioritizing the user's selected ingredients.

Return ONLY valid JSON in this exact shape:
{
  "recipes": [
    {
      "title": "",
      "ingredients": [""],
      "instructions": [""],
      "preparationTime": 0,
      "difficulty": "Easy"
    }
  ]
}

Rules:
- Return exactly five recipes.
- Each recipe must have 3 to 6 concise, executable instructions.
- Use plain English food names and realistic ingredient quantities where helpful.
- preparationTime must be a whole number of minutes.
- difficulty must be Easy, Medium, or Hard.
- Do not include markdown, commentary, nutrition claims, or text outside JSON.
''';
}

class AiRecipeException implements Exception {
  const AiRecipeException(this.message);

  final String message;

  @override
  String toString() => message;
}
