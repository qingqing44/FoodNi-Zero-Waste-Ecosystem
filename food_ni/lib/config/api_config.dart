import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central configuration for external API keys and settings.
///
/// Keys are loaded from the `.env` file at app startup via [flutter_dotenv].
/// Never hardcode values here.
class ApiConfig {
  ApiConfig._();

  /// Returns the Spoonacular API key from the `.env` file.
  ///
  /// Returns an empty string if the key is not set, allowing the app to
  /// degrade gracefully to Firebase-only recommendations.
  static String get spoonacularApiKey {
    final key = dotenv.maybeGet('SPOONACULAR_API_KEY') ?? '';
    return key.trim();
  }

  /// Whether a valid Spoonacular key is configured.
  static bool get hasSpoonacularKey => spoonacularApiKey.isNotEmpty;
}
