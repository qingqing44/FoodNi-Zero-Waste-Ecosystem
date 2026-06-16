import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/recipe.dart';

/// Fetches recipes stored in FoodNi's own Firestore [recipes] collection.
///
/// Each document should contain:
/// ```json
/// {
///   "title": "Tomato Omelette",
///   "imageUrl": "https://...",
///   "ingredients": ["egg", "tomato", "onion"],
///   "instructions": ["Beat eggs", "Cook tomatoes", "Combine"],
///   "preparationTime": 15,
///   "difficulty": "Easy"
/// }
/// ```
class FirebaseRecipeService {
  const FirebaseRecipeService();

  static const _collection = 'recipes';

  /// Fetches all documents from the [recipes] Firestore collection and maps
  /// them to [Recipe] objects with [source] set to `"firebase"`.
  ///
  /// Returns an empty list if the collection is empty or if any error occurs.
  Future<List<Recipe>> fetchFirebaseRecipes() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection(_collection).get();

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return Recipe.fromJson(
                {...data, 'source': 'firebase'},
                id: doc.id,
              );
            } catch (e) {
              // Skip malformed documents rather than failing the entire fetch.
              return null;
            }
          })
          .whereType<Recipe>()
          .toList();
    } on FirebaseException catch (e) {
      // Log and degrade gracefully — the hybrid service will fall back to
      // external recipes only.
      // ignore: avoid_print
      print('[FirebaseRecipeService] Firestore error: ${e.message}');
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('[FirebaseRecipeService] Unexpected error: $e');
      return [];
    }
  }
}
