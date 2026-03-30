import 'package:flutter/material.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/admin_page.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.login(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    bool isRequesting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Réinitialiser le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Entrez votre email pour recevoir un lien de réinitialisation.'),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isRequesting ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isRequesting
                  ? null
                  : () async {
                      if (emailController.text.isEmpty || !emailController.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez entrer un email valide.')),
                        );
                        return;
                      }

                      setDialogState(() => isRequesting = true);
                      try {
                        await _authService.forgotPassword(emailController.text);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Si un compte existe, un email a été envoyé.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                          );
                        }
                      } finally {
                        if (mounted) setDialogState(() => isRequesting = false);
                      }
                    },
              child: isRequesting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF121212), const Color(0xFF1E1E1E)]
                : [const Color(0xFFfcf1f1), const Color(0xFFfffcdd)],
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
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      'assets/images/locos.png',
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Title
                  Text(
                    'Accès Administrateur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      shadows: isDark ? [] : [
                        const Shadow(
                          blurRadius: 10.0,
                          color: Colors.black26,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Email Field
                  TextField(
                    controller: _emailController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: const Icon(Icons.email_outlined, color: accentColor),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Mot de passe',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: const Icon(Icons.lock_open_outlined, color: accentColor),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                    obscureText: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Login Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          onTap: _login,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: buttonGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9c4dea).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Connexion',
                                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  // Back Button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Retour',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black54),
                    ),
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