import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/recipe.dart';
import 'query_key_generator.dart';
import 'recipe_cache_service.dart';

/// Fetches recipe recommendations from the Spoonacular API with a Firestore
/// cache layer to minimise quota usage.
///
/// **Fetch priority**
/// 1. Generate a deterministic [queryKey] from [ingredients].
/// 2. Check [RecipeCacheService] — return cached results if still fresh.
/// 3. Only call Spoonacular when the cache is empty or expired.
/// 4. After a successful API response, persist results in Firestore.
///
/// **API key configuration**
/// Add your key to `.env` in the project root:
/// ```
/// SPOONACULAR_API_KEY=your_key_here
/// ```
/// If the key is absent the service returns an empty list so Firebase-only
/// recommendations continue to work.
class ExternalRecipeService {
  ExternalRecipeService({
    http.Client? client,
    RecipeCacheService? cacheService,
  }) : _client = client ?? http.Client(),
       _cache = cacheService ?? const RecipeCacheService();

  final http.Client _client;
  final RecipeCacheService _cache;

  static const _baseUrl = 'https://api.spoonacular.com';

  /// Maximum number of recipes to request per Spoonacular call.
  static const _maxResults = 15;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns recipes matching [ingredients], preferring the Firestore cache.
  ///
  /// Returns an empty list when:
  /// - [ingredients] is empty.
  /// - No API key is configured.
  /// - The cache is empty/expired and the API call fails.
  Future<List<Recipe>> fetchRecipesByIngredients(
    List<String> ingredients,
  ) async {
    if (ingredients.isEmpty) return [];

    // ── Step 1: Build deterministic query key ──────────────────────────────
    final queryKey = generateQueryKey(ingredients);

    // ── Step 2: Try Firestore cache first ──────────────────────────────────
    final cached = await _cache.getCachedRecipes(queryKey);
    if (cached.isNotEmpty) return cached;

    // ── Step 3: Guard — need an API key to call Spoonacular ────────────────
    if (!ApiConfig.hasSpoonacularKey) {
      debugPrint(
        '[Spoonacular] No API key configured — skipping external fetch.',
      );
      return [];
    }

    // ── Step 4: Fetch from Spoonacular ─────────────────────────────────────
    debugPrint('[Spoonacular] Fetching external recipes for key: $queryKey');

    try {
      final summaries = await _findByIngredients(ingredients);
      if (summaries.isEmpty) return [];

      final ids = summaries.map((r) => r['id'] as int).toList();
      final recipes = await _bulkInformation(ids);

      if (recipes.isEmpty) return [];

      // ── Step 5: Persist results in Firestore cache ─────────────────────
      await _cache.cacheRecipes(queryKey, recipes);
      debugPrint('[Spoonacular] Cached ${recipes.length} recipes.');

      return recipes;
    } on http.ClientException catch (e) {
      debugPrint('[Spoonacular] Network error: $e');
      return [];
    } catch (e) {
      debugPrint('[Spoonacular] Unexpected error: $e');
      return [];
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// `GET /recipes/findByIngredients` — returns a list of recipe summaries.
  Future<List<Map<String, dynamic>>> _findByIngredients(
    List<String> ingredients,
  ) async {
    final uri = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(
      queryParameters: {
        'apiKey': ApiConfig.spoonacularApiKey,
        'ingredients': ingredients.join(','),
        'number': '$_maxResults',
        'ranking': '1',
        'ignorePantry': 'true',
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode == 401) {
      debugPrint('[Spoonacular] Invalid API key (401).');
      return [];
    }
    if (response.statusCode == 402) {
      debugPrint('[Spoonacular] Daily quota exceeded (402).');
      return [];
    }
    if (response.statusCode != 200) {
      debugPrint(
        '[Spoonacular] findByIngredients failed: ${response.statusCode}',
      );
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  /// `GET /recipes/informationBulk` — returns full recipe details for [ids].
  Future<List<Recipe>> _bulkInformation(List<int> ids) async {
    final uri = Uri.parse('$_baseUrl/recipes/informationBulk').replace(
      queryParameters: {
        'apiKey': ApiConfig.spoonacularApiKey,
        'ids': ids.join(','),
        'includeNutrition': 'false',
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      debugPrint(
        '[Spoonacular] informationBulk failed: ${response.statusCode}',
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
        // Skip malformed entries silently.
      }
    }
    return results;
  }

  /// Converts a raw Spoonacular JSON object into a [Recipe].
  Recipe _mapSpoonacularRecipe(Map<String, dynamic> json) {
    final rawIngredients =
        (json['extendedIngredients'] as List<dynamic>? ?? [])
            .map(
              (i) => (i as Map<String, dynamic>)['name'] as String? ?? '',
            )
            .where((name) => name.isNotEmpty)
            .toList();

    final rawSteps =
        (json['analyzedInstructions'] as List<dynamic>? ?? [])
            .expand(
              (block) =>
                  ((block as Map<String, dynamic>)['steps']
                          as List<dynamic>? ??
                      []).map(
                    (s) =>
                        (s as Map<String, dynamic>)['step'] as String? ?? '',
                  ),
            )
            .where((step) => step.isNotEmpty)
            .toList();

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
