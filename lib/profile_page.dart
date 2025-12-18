import 'package:flutter/material.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/user_login_page.dart';
import 'package:fast_food_app/register_page.dart';
import 'package:fast_food_app/admin_page.dart';
import 'package:fast_food_app/order_history_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userRole;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
    });
    final loggedIn = await _authService.isAuthenticated();
    String? role;
    String? name;
    if (loggedIn) {
      role = await _authService.getUserRole();
      name = await _authService.getUserName();
    }
    setState(() {
      _isLoggedIn = loggedIn;
      _userRole = role;
      _userName = name;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    _checkAuthStatus();
  }

  Widget _buildOutlinedButton({
    required VoidCallback onPressed,
    required String text,
    required Color color,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        side: BorderSide(color: color, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFfcf1f1), Color(0xFFfffcdd)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _isLoggedIn ? _buildLoggedInView() : _buildLoggedOutView(),
                ),
              ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    const accentColor = Color(0xFF53c6fd);
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.person, size: 80, color: accentColor),
        const SizedBox(height: 20),
        Text(
          'Bienvenue, ${_userName ?? ''}!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: accentColor),
        ),
        const SizedBox(height: 50),
        GradientButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
            );
          },
          text: 'Mes Commandes',
          icon: Icons.receipt_long,
          gradient: buttonGradient,
        ),
        const SizedBox(height: 20),
        if (_userRole == 'admin')
          GradientButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminPage()),
              ).then((_) => _checkAuthStatus());
            },
            text: 'Panneau d\'administration',
            icon: Icons.admin_panel_settings,
            gradient: buttonGradient,
          ),
        const SizedBox(height: 20),
        _buildOutlinedButton(
          onPressed: _logout,
          text: 'Se déconnecter',
          color: accentColor,
        ),
      ],
    );
  }

  Widget _buildLoggedOutView() {
    const accentColor = Color(0xFF53c6fd);
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.person_off, size: 80, color: Colors.black38),
        const SizedBox(height: 20),
        const Text(
          'Vous n\'êtes pas connecté',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 40),
        GradientButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserLoginPage()),
            ).then((_) => _checkAuthStatus());
          },
          text: 'Se connecter',
          icon: Icons.login,
          gradient: buttonGradient,
        ),
        const SizedBox(height: 20),
        _buildOutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          },
          text: 'Créer un compte',
          color: accentColor,
        ),
      ],
    );
  }
}
