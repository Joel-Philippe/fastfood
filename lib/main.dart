import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for date formatting
import 'package:fast_food_app/auth_wrapper.dart'; // Import AuthWrapper

import 'package:fast_food_app/menu_customization_provider.dart';

late String baseUrl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize date formatting for the French locale
  await initializeDateFormatting('fr_FR', null);

  baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:5000';

  if (!kIsWeb) {
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHable_KEY'] ?? "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY";
    await Stripe.instance.applySettings();
  }


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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tacos Locos',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F), // Red
          primary: const Color(0xFFD32F2F), // Red
          secondary: const Color(0xFFFFC107), // Amber
          background: const Color(0xFFF5F5F5), // Light Grey
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F), // Red
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto', // Example font
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107), // Amber
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}
