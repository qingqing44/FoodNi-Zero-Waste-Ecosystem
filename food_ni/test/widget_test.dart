import 'package:flutter_test/flutter_test.dart';

import 'package:food_ni/inventory/food_status_utils.dart';

void main() {
  group('FoodStatusUtils suggested expiry', () {
    test('calculates produce expiry from purchase date', () {
      final purchaseDate = DateTime(2026, 6, 9);

      final expiryDate = FoodStatusUtils.suggestedExpiryDate(
        category: 'Produce',
        purchaseDate: purchaseDate,
      );

      expect(expiryDate, DateTime(2026, 6, 16));
    });

    test('uses fallback shelf life for unknown categories', () {
      final purchaseDate = DateTime(2026, 6, 9);

      final expiryDate = FoodStatusUtils.suggestedExpiryDate(
        category: 'Bakery',
        purchaseDate: purchaseDate,
      );

      expect(
        expiryDate,
        DateTime(
          2026,
          6,
          9 + FoodStatusUtils.defaultManualShelfLifeDays,
        ),
      );
    });

    test('does not calculate expiry without a category', () {
      final expiryDate = FoodStatusUtils.suggestedExpiryDate(
        category: null,
        purchaseDate: DateTime(2026, 6, 9),
      );

      expect(expiryDate, isNull);
    });

    test('treats dates on the same day as equal', () {
      expect(
        FoodStatusUtils.isSameDate(
          DateTime(2026, 6, 9, 8, 0),
          DateTime(2026, 6, 9, 21, 30),
        ),
        isTrue,
      );
    });
  });
}
