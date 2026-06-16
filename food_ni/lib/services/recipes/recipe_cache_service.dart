import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/recipe.dart';

/// Manages the two-collection Firestore cache for externally fetched recipes.
///
/// Collections:
/// - `external_recipes` — stores full recipe documents, keyed by [externalId].
/// - `recipe_queries`   — stores query → [List<externalId>] mappings.
///
/// Cache freshness: entries older than [_cacheTtl] are treated as expired.
class RecipeCacheService {
  const RecipeCacheService();

  static const _externalRecipes = 'external_recipes';
  static const _recipeQueries = 'recipe_queries';

  /// How long a cached result remains valid before a fresh Spoonacular
  /// request is triggered.
  static const _cacheTtl = Duration(days: 30);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns cached [Recipe] objects for [queryKey] if a fresh entry exists.
  ///
  /// Returns an empty list when:
  /// - No cache entry found for [queryKey].
  /// - The cache entry has expired (older than [_cacheTtl]).
  /// - Any Firestore error occurs.
  Future<List<Recipe>> getCachedRecipes(String queryKey) async {
    try {
      final db = FirebaseFirestore.instance;

      // ── Step 1: Look up the query document ─────────────────────────────
      final queryDoc =
          await db.collection(_recipeQueries).doc(queryKey).get();

      if (!queryDoc.exists) {
        debugPrint('[RecipeCache] Cache miss: $queryKey');
        return [];
      }

      final queryData = queryDoc.data()!;

      // ── Step 2: Check freshness ─────────────────────────────────────────
      final cachedAt = (queryData['cachedAt'] as Timestamp?)?.toDate();
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt) > _cacheTtl) {
        debugPrint('[RecipeCache] Cache expired: $queryKey');
        return [];
      }

      // ── Step 3: Fetch full recipe documents ─────────────────────────────
      final recipeIds =
          (queryData['recipeIds'] as List<dynamic>? ?? []).cast<String>();

      if (recipeIds.isEmpty) {
        debugPrint('[RecipeCache] Cache hit (empty set): $queryKey');
        return [];
      }

      // Firestore `whereIn` supports up to 30 items; we stay well below that.
      final snapshot = await db
          .collection(_externalRecipes)
          .where(FieldPath.documentId, whereIn: recipeIds)
          .get();

      final recipes = snapshot.docs
          .map((doc) {
            try {
              return Recipe.fromJson(doc.data(), id: doc.id);
            } catch (_) {
              return null;
            }
          })
          .whereType<Recipe>()
          .toList();

      debugPrint(
        '[RecipeCache] Cache hit: $queryKey (${recipes.length} recipes)',
      );
      return recipes;
    } catch (e) {
      debugPrint('[RecipeCache] Error reading cache for $queryKey: $e');
      return [];
    }
  }

  /// Persists [recipes] into Firestore and records the query mapping.
  ///
  /// Uses a [WriteBatch] to write all recipe documents and the query index
  /// document atomically. Silently no-ops on empty [recipes].
  Future<void> cacheRecipes(String queryKey, List<Recipe> recipes) async {
    if (recipes.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = Timestamp.now();
      final savedIds = <String>[];

      for (final recipe in recipes) {
        // Use the recipe's externalId as the Firestore document ID so that
        // re-fetching the same Spoonacular recipe never creates duplicates.
        final docId =
            recipe.id.isNotEmpty ? recipe.id : db.collection(_externalRecipes).doc().id;

        final docRef = db.collection(_externalRecipes).doc(docId);

        batch.set(
          docRef,
          {
            ...recipe.toJson(),
            'externalId': recipe.id,
            'queryKey': queryKey,
            'cachedAt': now,
          },
          SetOptions(merge: true), // won't overwrite if doc already exists
        );

        savedIds.add(docId);
      }

      // Write the query → recipe IDs mapping.
      batch.set(
        db.collection(_recipeQueries).doc(queryKey),
        {
          'queryKey': queryKey,
          'recipeIds': savedIds,
          'cachedAt': now,
        },
      );

      await batch.commit();
      debugPrint('[RecipeCache] Cached ${recipes.length} recipes for $queryKey');
    } catch (e) {
      // Caching failure must never break the calling flow.
      debugPrint('[RecipeCache] Error caching recipes for $queryKey: $e');
    }
  }
}
