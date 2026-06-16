import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../inventory/food_status_utils.dart';
import '../models/food_item.dart';
import '../services/recipes/recipe_service.dart';

class ExpiryNotificationService {
  ExpiryNotificationService._();

  static final ExpiryNotificationService instance =
      ExpiryNotificationService._();

  static const _channelId = 'food_expiry_reminders';
  static const _channelName = 'Food expiry reminders';
  static const _channelDescription = 'Reminders for food items before expiry';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _permissionRequested = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _configureTimezone();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );

      await _plugin.initialize(initializationSettings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
    }
  }

  Future<void> _configureTimezone() async {
    try {
      await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(FoodStatusUtils.malaysiaLocation());
    } catch (e) {
      debugPrint('Timezone lookup failed, using Asia/Kuala_Lumpur: $e');
      try {
        tz.setLocalLocation(FoodStatusUtils.malaysiaLocation());
      } catch (_) {}
    }
  }

  Future<void> requestPermissions() async {
    if (_permissionRequested) return;
    _permissionRequested = true;

    try {
      await initialize();
      if (defaultTargetPlatform != TargetPlatform.android) return;

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> scheduleExpiryReminder({
    required String itemId,
    required String foodName,
    required DateTime expiryDate,
  }) async {
    try {
      await initialize();
      if (!_isInitialized || kIsWeb) return;

      final cleanExpiry = FoodStatusUtils.dateOnly(expiryDate);
      final daysRemaining = FoodStatusUtils.daysRemaining(cleanExpiry);
      if (daysRemaining < 0) return;

      final scheduledDate = _reminderDateFor(cleanExpiry);
      if (scheduledDate == null) return;

      await _plugin.zonedSchedule(
        notificationIdForItem(itemId),
        'Food expiring soon',
        '$foodName is expiring soon. Check your inventory.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: itemId,
      );
    } catch (e) {
      debugPrint('Scheduling expiry reminder failed: $e');
    }
  }

  Future<void> cancelReminder(String itemId) async {
    try {
      await initialize();
      await _plugin.cancel(notificationIdForItem(itemId));
    } catch (e) {
      debugPrint('Canceling expiry reminder failed: $e');
    }
  }

  int notificationIdForItem(String itemId) {
    return itemId.hashCode & 0x7fffffff;
  }

  tz.TZDateTime? _reminderDateFor(DateTime expiryDate) {
    final malaysiaLocation = FoodStatusUtils.malaysiaLocation();
    final oneDayBeforeAtNine = tz.TZDateTime(
      malaysiaLocation,
      expiryDate.year,
      expiryDate.month,
      expiryDate.day - 1,
      9,
    );
    final now = tz.TZDateTime.now(malaysiaLocation);
    if (oneDayBeforeAtNine.isAfter(now)) {
      return oneDayBeforeAtNine;
    }
    return null;
  }

  /// Checks the inventory for items expiring in <= 3 days.
  /// If found, fetches recommended recipes and sends a single local
  /// notification. Only triggers once per day.
  Future<void> checkAndSendDailyExpiryNotifications() async {
    try {
      if (kIsWeb) return;
      await initialize();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final todayStr = FoodStatusUtils.malaysiaTodayDateOnly().toIso8601String();
      final lastChecked = prefs.getString('last_expiry_notification_date');

      if (lastChecked == todayStr) {
        return; // Already checked today
      }

      // Fetch user's inventory
      final snapshot = await FirebaseFirestore.instance
          .collection('foodItems')
          .where('userId', isEqualTo: user.uid)
          .get();

      final items = snapshot.docs
          .map((doc) => FoodItem.fromFirestore(doc.data(), doc.id))
          .toList();

      // Find items expiring in <= 3 days
      final expiringItems = <FoodItem>[];
      for (final item in items) {
        int? daysRemaining;
        if (item.expiryDate != null) {
          daysRemaining = FoodStatusUtils.daysRemaining(item.expiryDate!);
        } else {
          daysRemaining = item.estimatedDaysRemaining;
        }

        if (daysRemaining != null && daysRemaining >= 0 && daysRemaining <= 3) {
          expiringItems.add(item);
        }
      }

      if (expiringItems.isEmpty) {
        await prefs.setString('last_expiry_notification_date', todayStr);
        return;
      }

      // Fetch recipes
      final recipeService = RecipeService();
      final recipes = await recipeService.getRecommendedRecipes(items);

      final topRecipes = recipes
          .where((r) => r.expiringIngredientsUsed.isNotEmpty)
          .take(3)
          .toList();

      if (topRecipes.isNotEmpty) {
        final itemNames = expiringItems.map((i) => i.name).take(2).join(' and ');
        final recipeNames = topRecipes.map((r) => '• ${r.title}').join('\n');

        await _plugin.show(
          'daily_expiry'.hashCode,
          'Your $itemNames expires soon!',
          'Try:\n$recipeNames',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
        );
      }

      await prefs.setString('last_expiry_notification_date', todayStr);
    } catch (e) {
      debugPrint('Daily expiry notification failed: $e');
    }
  }
}
