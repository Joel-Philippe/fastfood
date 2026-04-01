import 'package:flutter/material.dart';
import 'package:fast_food_app/admin/manage_menu_page.dart';
import 'package:fast_food_app/admin_dashboard_page.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _hasChanges = false;

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _hasChanges);
    return false;
  }

  Widget _buildAdminCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    const accentColor = Color(0xFF53c6fd);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: accentColor),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: accentColor, size: 28),
                            onPressed: () => Navigator.pop(context, _hasChanges),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Administration',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grid of admin options
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                        padding: const EdgeInsets.all(24),
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.5 : 1.0,
                        children: [
                          _buildAdminCard(
                            label: 'Tableau de bord\nCommandes',
                            icon: Icons.dashboard_rounded,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                              );
                              if (result == true) {
                                setState(() {
                                  _hasChanges = true;
                                });
                              }
                            },
                          ),
                          _buildAdminCard(
                            label: 'Gérer le Menu',
                            icon: Icons.restaurant_menu_rounded,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ManageMenuPage()),
                              );
                              if (result == true) {
                                setState(() {
                                  _hasChanges = true;
                                });
                              }
                            },
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, duration: 600.ms, curve: Curves.easeOut).fadeIn(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}