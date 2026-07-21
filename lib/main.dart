import 'dart:math';
import 'package:fast_food_app/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:fast_food_app/order_tracking_page.dart';

// Handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

final LocalNotificationService localNotificationService =
    LocalNotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

const _lightShellStart = Color(0xFFFCF1F1);
const _lightShellEnd = Color(0xFFFFFCDD);
const _darkShell = Color(0xFF0B0F14);

Widget _appShellForTheme(BuildContext context, Widget? child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  return _AnimatedAppShell(
      isDark: isDark, child: child ?? const SizedBox.shrink());
}

class _AnimatedAppShell extends StatefulWidget {
  final bool isDark;
  final Widget child;

  const _AnimatedAppShell({required this.isDark, required this.child});

  @override
  State<_AnimatedAppShell> createState() => _AnimatedAppShellState();
}

class _AnimatedAppShellState extends State<_AnimatedAppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDark) {
      return ColoredBox(color: _darkShell, child: widget.child);
    }

    final softColors = <Color>[
      Colors.white,
      Color.lerp(_lightShellStart, Colors.white, 0.34)!,
      Color.lerp(_lightShellEnd, Colors.white, 0.50)!,
      Colors.white,
      Color.lerp(_lightShellStart, _lightShellEnd, 0.45)!.withOpacity(0.72),
      Color.lerp(_lightShellEnd, Colors.white, 0.28)!,
    ];

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: softColors,
              stops: const [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
              begin: Alignment(cos(t) * 0.65, sin(t) * 0.65),
              end: Alignment(cos(t + pi) * 0.65, sin(t + pi) * 0.65),
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Five Minutes',
      debugShowCheckedModeBanner: false,
      builder: _appShellForTheme,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF53c6fd),
          brightness: Brightness.light,
          surface: Colors.transparent,
          onSurface: Colors.black87,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF53c6fd),
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.72),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
          onPrimary: Colors.white,
          secondary: const Color(0xFF53c6fd),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        canvasColor: const Color(0xFF121212),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF121212),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF121212),
          modalBackgroundColor: Color(0xFF121212),
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white70,
          textColor: Colors.white,
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token'];
          if (token != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordPage(token: token),
            );
          }
        }
        if (settings.name != null && settings.name!.startsWith('/track/')) {
          final uri = Uri.parse(settings.name!);
          final token =
              uri.pathSegments.length >= 2 ? uri.pathSegments[1] : null;
          if (token != null && token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => OrderTrackingPage(trackingToken: token),
            );
          }
        }
        return null;
      },
    );
  }
}
