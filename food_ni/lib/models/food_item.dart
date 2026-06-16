import '../inventory/food_status_utils.dart';

/// Represents a single food item in the user's inventory.
/// 
/// Used primarily by the recipe recommendation engine to calculate
/// expiry priorities and waste reduction scores.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    this.expiryDate,
    this.estimatedDaysRemaining,
    required this.freshnessStatus,
  });

  /// Unique Firestore document ID.
  final String id;

  /// The normalized, lowercased name of the food (e.g. "tomato").
  final String name;

  /// Parsed expiry date, if available.
  final DateTime? expiryDate;

  /// Fallback integer for estimated days remaining if date is absent.
  final int? estimatedDaysRemaining;

  /// Freshness status label (e.g. "Fresh", "Expiring Soon", "Expired").
  final String freshnessStatus;

  /// Creates a [FoodItem] from a raw Firestore document map.
  factory FoodItem.fromFirestore(Map<String, dynamic> data, String id) {
    final rawName = data['foodName'] as String?;
    final name = rawName?.trim().toLowerCase() ?? '';
    
    final expiryDate = FoodStatusUtils.parseExpiryDate(data['expiryDate'] as String?);
    final estimatedDaysRemaining = (data['estimatedDaysRemaining'] as num?)?.toInt();
    final freshnessStatus = FoodStatusUtils.statusFromItemData(data);

    return FoodItem(
      id: id,
      name: name,
      expiryDate: expiryDate,
      estimatedDaysRemaining: estimatedDaysRemaining,
      freshnessStatus: freshnessStatus,
    );
  }
}
