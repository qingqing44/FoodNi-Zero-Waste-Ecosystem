/// Represents a recipe that can originate from either the FoodNi Firebase
/// collection or an external API (e.g. Spoonacular).
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.preparationTime,
    required this.difficulty,
    required this.source,
    this.matchPercentage = 0.0,
  });

  /// Unique identifier (Firestore doc ID or external API ID).
  final String id;

  final String title;

  /// Network URL for the recipe's cover image. May be empty.
  final String imageUrl;

  /// List of ingredient names, e.g. ["egg", "tomato", "onion"].
  final List<String> ingredients;

  /// Step-by-step cooking instructions.
  final List<String> instructions;

  /// Estimated preparation time in minutes.
  final int preparationTime;

  /// Human-readable difficulty label, e.g. "Easy", "Medium", "Hard".
  final String difficulty;

  /// Where this recipe came from: "firebase" or "external".
  final String source;

  /// Percentage of inventory ingredients that appear in [ingredients].
  /// Calculated by [RecipeService] after fetching; defaults to 0.
  final double matchPercentage;

  // ── Deserialization ────────────────────────────────────────────────────────

  factory Recipe.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return Recipe(
      id: id.isNotEmpty ? id : (json['id'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      ingredients: _parseStringList(json['ingredients']),
      instructions: _parseStringList(json['instructions']),
      preparationTime: (json['preparationTime'] as num?)?.toInt() ?? 0,
      difficulty: json['difficulty'] as String? ?? 'Unknown',
      source: json['source'] as String? ?? 'firebase',
      matchPercentage: (json['matchPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'imageUrl': imageUrl,
    'ingredients': ingredients,
    'instructions': instructions,
    'preparationTime': preparationTime,
    'difficulty': difficulty,
    'source': source,
    'matchPercentage': matchPercentage,
  };

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns a copy of this recipe with [matchPercentage] overridden.
  Recipe withMatch(double percentage) => copyWith(matchPercentage: percentage);

  Recipe copyWith({
    String? id,
    String? title,
    String? imageUrl,
    List<String>? ingredients,
    List<String>? instructions,
    int? preparationTime,
    String? difficulty,
    String? source,
    double? matchPercentage,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      preparationTime: preparationTime ?? this.preparationTime,
      difficulty: difficulty ?? this.difficulty,
      source: source ?? this.source,
      matchPercentage: matchPercentage ?? this.matchPercentage,
    );
  }

  /// Safely coerce a JSON field that may be a [List<dynamic>] into
  /// a [List<String>].
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').toList();
    }
    return [];
  }
}
