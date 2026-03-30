import 'package:fast_food_app/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fast_food_app/auth_wrapper.dart';

import 'package:fast_food_app/menu_customization_provider.dart';
import 'package:fast_food_app/services/auth_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'package:fast_food_app/services/local_notification_service.dart';
import 'package:fast_food_app/reset_password_page.dart';
import 'dart:html' as html;

// Handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

final LocalNotificationService localNotificationService = LocalNotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // URL cleaning is handled in CheckoutPage for now
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await localNotificationService.initialize();

  await AppConfig.init();
  await initializeDateFormatting('fr_FR', null);

  final stripeKey = AppConfig.stripePublishableKey;
  if (stripeKey != null && stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    await Stripe.instance.applySettings();
  }

  await _setupFirebaseMessaging();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuCustomizationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _setupFirebaseMessaging() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized || 
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }

      if (token != null) {
        final authService = AuthService();
        if (await authService.isAuthenticated()) {
          try {
            await authService.updateFCMToken(token);
          } catch (e) {
            debugPrint('Failed to send FCM token to backend: $e');
          }
        }
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        localNotificationService.showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? '',
          body: message.notification!.body ?? '',
          payload: message.data['orderId'],
        );
      }
    });
  } catch (e) {
    debugPrint('Critical error in Firebase Messaging setup: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tacos Locos',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF53c6fd),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF53c6fd),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF53c6fd),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF53c6fd),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF53c6fd),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token'];
          if (token != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordPage(token: token),
            );
          }
        }
        return null;
      },
    );
  }
}
