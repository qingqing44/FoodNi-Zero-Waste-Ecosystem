import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class FoodStatusUtils {
  static const fresh = 'Fresh';
  static const nearExpiry = 'Near Expiry';
  static const expiringSoon = 'Expiring Soon';
  static const expired = 'Expired';
  static const malaysiaTimeZoneName = 'Asia/Kuala_Lumpur';
  static const int defaultManualShelfLifeDays = 7;
  static const Map<String, int> _manualShelfLifeDaysByCategory = {
    'produce': 7,
    'main course': 3,
    'prepared meal': 2,
    'meat & seafood': 2,
    'dessert/pastry': 5,
    'frozen': 90,
    'packaged beverages': 30,
    'fruit': 7,
    'uncategorized': defaultManualShelfLifeDays,
  };

  static final DateFormat _formatter = DateFormat('MMM dd, yyyy');
  static bool _timeZonesInitialized = false;

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDate(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    return dateOnly(left) == dateOnly(right);
  }

  static tz.Location malaysiaLocation() {
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    return tz.getLocation(malaysiaTimeZoneName);
  }

  static DateTime malaysiaNow() {
    final now = tz.TZDateTime.now(malaysiaLocation());
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  static DateTime malaysiaTodayDateOnly() {
    final malaysiaNow = tz.TZDateTime.now(malaysiaLocation());
    return DateTime(malaysiaNow.year, malaysiaNow.month, malaysiaNow.day);
  }

  static DateTime? parseExpiryDate(String? value) {
    if (value == null || value.trim().isEmpty || value == 'N/A') return null;
    try {
      return dateOnly(_formatter.parse(value));
    } catch (_) {
      return null;
    }
  }

  static String formatExpiryDate(DateTime date) {
    return _formatter.format(date);
  }

  static String normalizeCategory(String? category) {
    return (category ?? '').trim().toLowerCase();
  }

  static int? suggestedShelfLifeDaysForCategory(String? category) {
    final normalizedCategory = normalizeCategory(category);
    if (normalizedCategory.isEmpty) return null;
    return _manualShelfLifeDaysByCategory[normalizedCategory] ??
        defaultManualShelfLifeDays;
  }

  static DateTime? suggestedExpiryDate({
    required String? category,
    required DateTime? purchaseDate,
  }) {
    if (purchaseDate == null) return null;

    final shelfLifeDays = suggestedShelfLifeDaysForCategory(category);
    if (shelfLifeDays == null) return null;

    return dateOnly(purchaseDate).add(Duration(days: shelfLifeDays));
  }

  static int daysRemaining(DateTime expiryDate, {DateTime? today}) {
    final cleanToday = today == null
        ? malaysiaTodayDateOnly()
        : dateOnly(today);
    final cleanExpiry = dateOnly(expiryDate);
    return cleanExpiry.difference(cleanToday).inDays;
  }

  static int? daysRemainingFromString(String? expiryDate, {DateTime? today}) {
    final parsedDate = parseExpiryDate(expiryDate);
    if (parsedDate == null) return null;
    return daysRemaining(parsedDate, today: today);
  }

  static String statusForDays(int daysRemaining) {
    if (daysRemaining < 0) return expired;
    if (daysRemaining <= 3) return expiringSoon;
    if (daysRemaining <= 7) return nearExpiry;
    return fresh;
  }

  static String statusForExpiryDate(DateTime expiryDate, {DateTime? today}) {
    return statusForDays(daysRemaining(expiryDate, today: today));
  }

  static String statusFromItemData(Map<String, dynamic> data) {
    final expiryDays = daysRemainingFromString(data['expiryDate'] as String?);
    if (expiryDays != null) return statusForDays(expiryDays);

    final storedDays = (data['estimatedDaysRemaining'] as num?)?.toInt();
    if (storedDays != null) return statusForDays(storedDays);

    return normalizeStatus(data['freshnessStatus'] as String?);
  }

  static String normalizeStatus(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    if (value == 'fresh') return fresh;
    if (value == 'near expiry' || value == 'near-expiry' || value == 'good') {
      return nearExpiry;
    }
    if (value == 'expiring' ||
        value == 'expiring soon' ||
        value.contains('consume')) {
      return expiringSoon;
    }
    if (value == 'expired' || value == 'spoiled') return expired;
    return 'Unknown';
  }

  static int freshnessScoreForStatus(String status) {
    if (status == fresh) return 100;
    if (status == nearExpiry) return 70;
    if (status == expiringSoon) return 40;
    if (status == expired) return 0;
    return 0;
  }

  static int freshnessScoreForDays(int daysRemaining) {
    return freshnessScoreForStatus(statusForDays(daysRemaining));
  }

  static Color statusColor(String? status) {
    final normalizedStatus = normalizeStatus(status);
    if (normalizedStatus == fresh) return const Color(0xFF34A853);
    if (normalizedStatus == nearExpiry) return const Color(0xFFF9A825);
    if (normalizedStatus == expiringSoon) return const Color(0xFFF57C00);
    if (normalizedStatus == expired) return Colors.red;
    return Colors.grey;
  }

  static bool isAttentionStatus(String? status) {
    final normalizedStatus = normalizeStatus(status);
    return normalizedStatus == nearExpiry || normalizedStatus == expiringSoon;
  }
}
