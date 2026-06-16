import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'notifications/expiry_notification_service.dart';
import 'services/recipes/recipe_seeder.dart';

const clientId =
    '599901055825-u3im4t71dc6adlvguikbgufduf726bar.apps.googleusercontent.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env before anything else.
  // mergeWith: {} keeps existing process env vars on non-Flutter platforms.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional — the app runs without a Spoonacular key,
    // falling back to Firebase-only recommendations.
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await ExpiryNotificationService.instance.initialize();
  } catch (_) {
    // Notification setup should not block the app from launching.
  }

  // Seed the Firestore recipes collection on first launch.
  // Exits immediately if recipes already exist (idempotent).
  try {
    await RecipeSeeder.seedRecipesIfNeeded();
  } catch (_) {
    // Seeding failure must never prevent the app from starting.
  }

  runApp(const MyApp(clientId: clientId));
}
