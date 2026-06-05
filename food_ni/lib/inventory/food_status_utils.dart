import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class FoodStatusUtils {
  static const fresh = 'Fresh';
  static const expiring = 'Expiring';
  static const expired = 'Expired';
  static const malaysiaTimeZoneName = 'Asia/Kuala_Lumpur';

  static final DateFormat _formatter = DateFormat('MMM dd, yyyy');
  static bool _timeZonesInitialized = false;

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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
    if (daysRemaining <= 3) return expiring;
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
    if (value == 'expiring' || value == 'good' || value.contains('consume')) {
      return expiring;
    }
    if (value == 'expired' || value == 'spoiled') return expired;
    return 'Unknown';
  }

  static int freshnessScoreForStatus(String status) {
    if (status == fresh) return 100;
    if (status == expiring) return 60;
    if (status == expired) return 0;
    return 0;
  }

  static int freshnessScoreForDays(int daysRemaining) {
    return freshnessScoreForStatus(statusForDays(daysRemaining));
  }

  static Color statusColor(String? status) {
    final normalizedStatus = normalizeStatus(status);
    if (normalizedStatus == fresh) return const Color(0xFF34A853);
    if (normalizedStatus == expiring) return Colors.orange;
    if (normalizedStatus == expired) return Colors.red;
    return Colors.grey;
  }
}
