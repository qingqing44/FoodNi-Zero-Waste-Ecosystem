import '../../inventory/food_status_utils.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';

/// Service to calculate food waste reduction priorities.
class ExpiryPriorityService {
  const ExpiryPriorityService._();

  /// Calculates the expiry priority (0-100) for a single [FoodItem].
  ///
  /// Points system:
  /// ≤ 1 day     → 100 points
  /// ≤ 3 days    → 80 points
  /// ≤ 7 days    → 50 points
  /// ≤ 14 days   → 30 points
  /// > 14 days   → 10 points
  /// Expired     → 0 points (avoid suggesting spoiled food)
  static int expiryPriority(FoodItem item) {
    int? daysRemaining;

    if (item.expiryDate != null) {
      daysRemaining = FoodStatusUtils.daysRemaining(item.expiryDate!);
    } else {
      daysRemaining = item.estimatedDaysRemaining;
    }

    if (daysRemaining == null) {
      return 10; // Default low priority if no date is set.
    }

    if (daysRemaining < 0) return 0;
    if (daysRemaining <= 1) return 100;
    if (daysRemaining <= 3) return 80;
    if (daysRemaining <= 7) return 50;
    if (daysRemaining <= 14) return 30;
    return 10;
  }

  /// Calculates a normalized waste reduction score (0-100) for a [Recipe].
  ///
  /// Sums the [expiryPriority] of all inventory items matched in the recipe,
  /// then normalizes it against the maximum possible score if all ingredients
  /// were urgently expiring (100 points each).
  static double calculateWasteReductionScore(
    Recipe recipe,
    List<FoodItem> inventory,
  ) {
    if (recipe.ingredients.isEmpty) return 0.0;

    int totalPriority = 0;
    final normalizedRecipeIngredients =
        recipe.ingredients.map((i) => i.trim().toLowerCase()).toSet();

    for (final ingredient in normalizedRecipeIngredients) {
      // Find a matching inventory item for this ingredient
      final matchingItems = inventory.where((item) {
        final normalizedItemName = item.name;
        // Simple substring matching: does the recipe ingredient string contain
        // the inventory item name, or vice versa?
        return ingredient.contains(normalizedItemName) ||
            normalizedItemName.contains(ingredient);
      }).toList();

      if (matchingItems.isNotEmpty) {
        // If multiple matches (e.g. two cartons of milk), pick the one that expires soonest (highest priority)
        int maxPriority = 0;
        for (final match in matchingItems) {
          final priority = expiryPriority(match);
          if (priority > maxPriority) {
            maxPriority = priority;
          }
        }
        totalPriority += maxPriority;
      }
    }

    final maxPossibleScore = recipe.ingredients.length * 100;
    if (maxPossibleScore == 0) return 0.0;

    final score = (totalPriority / maxPossibleScore) * 100;
    return score.clamp(0.0, 100.0);
  }

  /// Identifies specific inventory ingredients used in this [Recipe] that
  /// expire in 7 days or less.
  static List<String> getExpiringIngredientsUsed(
    Recipe recipe,
    List<FoodItem> inventory,
  ) {
    final expiringNames = <String>{};
    final normalizedRecipeIngredients =
        recipe.ingredients.map((i) => i.trim().toLowerCase()).toSet();

    for (final item in inventory) {
      int? daysRemaining;
      if (item.expiryDate != null) {
        daysRemaining = FoodStatusUtils.daysRemaining(item.expiryDate!);
      } else {
        daysRemaining = item.estimatedDaysRemaining;
      }

      // Ignore expired or safe items
      if (daysRemaining == null || daysRemaining < 0 || daysRemaining > 7) {
        continue;
      }

      final normalizedItemName = item.name;
      for (final ingredient in normalizedRecipeIngredients) {
        if (ingredient.contains(normalizedItemName) ||
            normalizedItemName.contains(ingredient)) {
          // Keep original casing for display, fallback to ingredient name if item name is empty
          expiringNames.add(item.name.isNotEmpty ? _capitalize(item.name) : _capitalize(ingredient));
          break;
        }
      }
    }

    return expiringNames.toList()..sort();
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
