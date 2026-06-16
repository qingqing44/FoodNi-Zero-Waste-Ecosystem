/// Generates a deterministic, normalised cache key from a list of ingredients.
///
/// The key is used to look up and store results in the Firestore
/// `recipe_queries` collection so that identical ingredient sets always map
/// to the same query document regardless of order or casing.
///
/// Algorithm:
/// 1. Lowercase each ingredient.
/// 2. Trim surrounding whitespace.
/// 3. Remove empty strings and duplicates.
/// 4. Sort alphabetically.
/// 5. Join with `_`.
///
/// Example:
/// ```dart
/// generateQueryKey(["Tomato", "Egg", "egg", "Bread"]);
/// // → "bread_egg_tomato"
/// ```
String generateQueryKey(List<String> ingredients) {
  final normalized = ingredients
      .map((i) => i.trim().toLowerCase())
      .where((i) => i.isNotEmpty)
      .toSet() // deduplicate
      .toList()
    ..sort();

  return normalized.join('_');
}
