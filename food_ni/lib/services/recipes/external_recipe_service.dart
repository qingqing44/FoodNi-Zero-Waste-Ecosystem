import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/recipe.dart';

/// Fetches recipe recommendations from the Spoonacular API based on a list of
/// inventory ingredient names.
///
/// **API key configuration**
/// The API key is injected at build time via `--dart-define`:
/// ```
/// flutter run --dart-define=SPOONACULAR_API_KEY=<your_key>
/// flutter build apk --dart-define=SPOONACULAR_API_KEY=<your_key>
/// ```
/// If no key is provided the service returns an empty list so that Firebase
/// recipes continue to work in isolation.
class ExternalRecipeService {
  ExternalRecipeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Injected at build time. Empty string when not configured.
  static const _apiKey = String.fromEnvironment('SPOONACULAR_API_KEY');

  static const _baseUrl = 'https://api.spoonacular.com';

  /// Maximum number of recipes to request per API call.
  static const _maxResults = 15;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches recipes from Spoonacular that match the given [ingredients].
  ///
  /// Performs two requests:
  /// 1. `findByIngredients` — returns recipe summaries.
  /// 2. `bulk information` — fetches full instructions for those recipes.
  ///
  /// Returns an empty list if the API key is absent, the network fails,
  /// or Spoonacular returns a non-200 status.
  Future<List<Recipe>> fetchRecipesByIngredients(
    List<String> ingredients,
  ) async {
    if (_apiKey.isEmpty) {
      // No key configured — skip external fetch silently.
      return [];
    }

    if (ingredients.isEmpty) return [];

    try {
      // ── Step 1: Find recipe IDs by ingredients ─────────────────────────
      final summaries = await _findByIngredients(ingredients);
      if (summaries.isEmpty) return [];

      final ids = summaries.map((r) => r['id'] as int).toList();

      // ── Step 2: Fetch full information (includes instructions) ─────────
      final detailedRecipes = await _bulkInformation(ids);

      return detailedRecipes;
    } on http.ClientException catch (e) {
      // Network-level errors (no connection, timeout, etc.)
      // ignore: avoid_print
      print('[ExternalRecipeService] Network error: $e');
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('[ExternalRecipeService] Unexpected error: $e');
      return [];
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Calls `GET /recipes/findByIngredients` and returns the raw JSON list.
  Future<List<Map<String, dynamic>>> _findByIngredients(
    List<String> ingredients,
  ) async {
    final uri = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'ingredients': ingredients.join(','),
        'number': '$_maxResults',
        'ranking': '1', // maximize used ingredients
        'ignorePantry': 'true',
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode == 402) {
      // Daily quota exceeded — treat as empty, not an error crash.
      // ignore: avoid_print
      print('[ExternalRecipeService] Spoonacular quota exceeded (402).');
      return [];
    }

    if (response.statusCode != 200) {
      // ignore: avoid_print
      print(
        '[ExternalRecipeService] findByIngredients failed: '
        '${response.statusCode}',
      );
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Calls `GET /recipes/informationBulk` for the given [ids] and maps the
  /// response to [Recipe] objects with [source] set to `"external"`.
  Future<List<Recipe>> _bulkInformation(List<int> ids) async {
    final uri = Uri.parse('$_baseUrl/recipes/informationBulk').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'ids': ids.join(','),
        'includeNutrition': 'false',
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      // ignore: avoid_print
      print(
        '[ExternalRecipeService] informationBulk failed: '
        '${response.statusCode}',
      );
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    final results = <Recipe>[];
    for (final item in decoded.cast<Map<String, dynamic>>()) {
      try {
        results.add(_mapSpoonacularRecipe(item));
      } catch (_) {
        // Skip malformed entries.
      }
    }
    return results;
  }

  /// Converts a Spoonacular recipe JSON object into a [Recipe].
  Recipe _mapSpoonacularRecipe(Map<String, dynamic> json) {
    // Extract ingredient names from extendedIngredients array.
    final rawIngredients =
        (json['extendedIngredients'] as List<dynamic>? ?? [])
            .map((i) => (i as Map<String, dynamic>)['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();

    // Extract instructions from analyzedInstructions → steps.
    final rawSteps = (json['analyzedInstructions'] as List<dynamic>? ?? [])
        .expand(
          (block) =>
              ((block as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [])
                  .map((s) => (s as Map<String, dynamic>)['step'] as String? ?? ''),
        )
        .where((step) => step.isNotEmpty)
        .toList();

    // Fall back to a plain summary if no steps were parsed.
    final instructions = rawSteps.isNotEmpty
        ? rawSteps
        : ['See full recipe at: ${json['sourceUrl'] ?? ''}'];

    return Recipe(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      ingredients: rawIngredients,
      instructions: instructions,
      preparationTime: (json['readyInMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _mapDifficulty(json['readyInMinutes'] as num?),
      source: 'external',
    );
  }

  /// Heuristically maps preparation time to a difficulty label.
  String _mapDifficulty(num? minutes) {
    if (minutes == null) return 'Unknown';
    if (minutes <= 20) return 'Easy';
    if (minutes <= 45) return 'Medium';
    return 'Hard';
  }
}
