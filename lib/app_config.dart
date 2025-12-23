import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String? _baseUrl;
  static String? _stripePublishableKey;

  static Future<void> init() async {
    await dotenv.load(fileName: ".env");

    // Load Base URL
    _baseUrl = dotenv.env['BASE_URL'];

    // Load Stripe Key
    _stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  }

  static String get baseUrl {
    if (_baseUrl != null && _baseUrl!.isNotEmpty) {
      return _baseUrl!;
    }

    // Fallback for development environment
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }

  static String? get stripePublishableKey {
    return _stripePublishableKey;
  }
}
