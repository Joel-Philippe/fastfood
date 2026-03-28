import 'package:flutter/material.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/user_login_page.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  const ResetPasswordPage({super.key, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit faire au moins 6 caractères.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.resetPassword(widget.token, _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé avec succès ! Connectez-vous maintenant.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UserLoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFfcf1f1), Color(0xFFfffcdd)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nouveau mot de passe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Veuillez choisir votre nouveau mot de passe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 50),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline, color: accentColor),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_clock_outlined, color: accentColor),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GradientButton(
                          onPressed: _resetPassword,
                          text: 'Réinitialiser',
                          icon: Icons.check_circle_outline,
                          gradient: buttonGradient,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
