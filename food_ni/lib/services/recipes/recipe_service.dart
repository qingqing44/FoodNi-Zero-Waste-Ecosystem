import '../../models/recipe.dart';
import 'firebase_recipe_service.dart';
import 'external_recipe_service.dart';

/// Orchestrates recipe recommendations from multiple sources.
///
/// **Hybrid strategy**
/// 1. Fetch all Firebase recipes and score them.
/// 2. If there are already ≥ [_minFirebaseResults] Firebase recipes with a
///    match percentage of ≥ [_minMatchThreshold], skip the external call.
/// 3. Otherwise fetch from Spoonacular concurrently with the Firebase fetch.
/// 4. Merge, sort, and return the top [_maxResults].
///
/// Results are **cached in memory** for the app session so that navigating
/// back to the Home screen does not trigger repeat API calls.
class RecipeService {
  RecipeService({
    FirebaseRecipeService? firebaseService,
    ExternalRecipeService? externalService,
  }) : _firebase = firebaseService ?? const FirebaseRecipeService(),
       _external = externalService ?? ExternalRecipeService();

  final FirebaseRecipeService _firebase;
  final ExternalRecipeService _external;

  // ── Configuration ──────────────────────────────────────────────────────────

  /// Minimum number of strong Firebase results before skipping Spoonacular.
  static const _minFirebaseResults = 10;

  /// A Firebase result is "strong" when its match % is at least this value.
  static const _minMatchThreshold = 50.0;

  /// Maximum recipes returned to the caller.
  static const _maxResults = 20;

  // ── Session cache ──────────────────────────────────────────────────────────

  List<Recipe>? _cache;

  /// Invalidates the in-memory cache (useful for pull-to-refresh).
  void invalidateCache() => _cache = null;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns up to [_maxResults] recipes ranked by ingredient match percentage.
  ///
  /// [inventoryIngredients] — lowercase, trimmed ingredient names extracted
  /// from the current user's Firestore food inventory.
  Future<List<Recipe>> getRecommendedRecipes(
    List<String> inventoryIngredients,
  ) async {
    // Return cached results if available.
    if (_cache != null) return _cache!;

    if (inventoryIngredients.isEmpty) return [];

    // ── Step 1 & 2: Fetch Firebase recipes and score them ──────────────────
    final firebaseRaw = await _firebase.fetchFirebaseRecipes();
    final firebaseScored = _scoreAndSort(firebaseRaw, inventoryIngredients);

    // Count how many Firebase recipes meet our "strong match" threshold.
    final strongFirebaseCount = firebaseScored
        .where((r) => r.matchPercentage >= _minMatchThreshold)
        .length;

    // ── Step 3 & 4: Conditionally fetch external recipes ───────────────────
    List<Recipe> externalScored = [];

    if (strongFirebaseCount < _minFirebaseResults) {
      // Not enough good Firebase results — fetch from Spoonacular.
      final externalRaw = await _external.fetchRecipesByIngredients(
        inventoryIngredients,
      );
      externalScored = _scoreAndSort(externalRaw, inventoryIngredients);
    }

    // ── Step 5: Merge ──────────────────────────────────────────────────────
    final merged = [...firebaseScored, ...externalScored];

    // ── Step 6: Sort — highest match first; Firebase before external on tie ─
    merged.sort((a, b) {
      final matchComp = b.matchPercentage.compareTo(a.matchPercentage);
      if (matchComp != 0) return matchComp;
      // Firebase recipes have priority on equal scores.
      if (a.source == 'firebase' && b.source != 'firebase') return -1;
      if (b.source == 'firebase' && a.source != 'firebase') return 1;
      return 0;
    });

    // ── Step 7: Limit & cache ──────────────────────────────────────────────
    _cache = merged.take(_maxResults).toList();
    return _cache!;
  }

  // ── Ingredient matching ────────────────────────────────────────────────────

  /// Calculates what percentage of [recipeIngredients] are covered by items
  /// in the user's [inventory].
  ///
  /// Comparison is case-insensitive and whitespace-normalized.
  ///
  /// Formula:
  /// ```
  /// matchPercentage = matchedCount / totalRecipeIngredients × 100
  /// ```
  static double calculateMatchPercentage(
    List<String> inventory,
    List<String> recipeIngredients,
  ) {
    if (recipeIngredients.isEmpty) return 0.0;

    // Normalize inventory once for efficiency.
    final normalizedInventory =
        inventory.map(_normalize).toSet();

    int matched = 0;
    for (final ingredient in recipeIngredients) {
      if (normalizedInventory.contains(_normalize(ingredient))) {
        matched++;
      }
    }

    return (matched / recipeIngredients.length) * 100;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Attaches a match percentage to each recipe and sorts descending.
  List<Recipe> _scoreAndSort(
    List<Recipe> recipes,
    List<String> inventory,
  ) {
    return recipes
        .map(
          (r) => r.withMatch(
            calculateMatchPercentage(inventory, r.ingredients),
          ),
        )
        .toList()
      ..sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
  }

  /// Normalises a string for comparison: lowercase + collapsed whitespace.
  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
