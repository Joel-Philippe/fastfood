import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageInfoPages extends StatefulWidget {
  final VoidCallback? onRefresh;
  const ManageInfoPages({super.key, this.onRefresh});

  @override
  State<ManageInfoPages> createState() => _ManageInfoPagesState();
}

class _ManageInfoPagesState extends State<ManageInfoPages> {
  final MongoService _mongoService = MongoService();
  late Future<List<InfoPage>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _refreshPages();
  }

  void _refreshPages() {
    setState(() {
      _pagesFuture = _mongoService.getInfoPagesAdmin();
    });
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPageDialog(),
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<InfoPage>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucune page d\'info.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black54)));
          }

          final pages = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(_getIconData(page.icon), color: accentColor),
                  title: Text(page.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(page.isVisible ? 'Visible' : 'Masquée', style: TextStyle(color: page.isVisible ? Colors.green : Colors.red)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: accentColor), onPressed: () => _showPageDialog(page: page)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deletePage(page.id)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'info': return Icons.info_outline;
      case 'restaurant': return Icons.restaurant;
      case 'delivery': return Icons.delivery_dining;
      case 'contact': return Icons.contact_support_outlined;
      case 'history': return Icons.history;
      case 'star': return Icons.star_border;
      default: return Icons.info_outline;
    }
  }

  void _deletePage(String id) async {
    try {
      await _mongoService.deleteInfoPage(id);
      _refreshPages();
      widget.onRefresh?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showPageDialog({InfoPage? page}) {
    final isEditing = page != null;
    final titleController = TextEditingController(text: page?.title);
    final contentController = TextEditingController(text: page?.content);
    String selectedIcon = page?.icon ?? 'info';
    bool isVisible = page?.isVisible ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(isEditing ? 'Modifier la page' : 'Nouvelle page', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController, 
                  decoration: const InputDecoration(
                    labelText: 'Titre de la page',
                    hintText: 'Ex: Notre Histoire, Nos Engagements...',
                    border: OutlineInputBorder(),
                  ), 
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87)
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: contentController, 
                  decoration: const InputDecoration(
                    labelText: 'Contenu de la page',
                    hintText: 'Rédigez ici les informations détaillées pour vos clients...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ), 
                  maxLines: 12, // Agrandissement pour la rédaction
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
                DropdownButton<String>(
                  value: selectedIcon,
                  dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  items: ['info', 'restaurant', 'delivery', 'contact', 'history', 'star'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Row(children: [Icon(_getIconData(val), color: const Color(0xFF53c6fd)), const SizedBox(width: 10), Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87))]),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedIcon = val!),
                ),
                SwitchListTile(
                  title: Text('Visible', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  value: isVisible,
                  onChanged: (val) => setDialogState(() => isVisible = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final newPage = InfoPage(
                  id: page?.id ?? '',
                  title: titleController.text,
                  content: contentController.text,
                  icon: selectedIcon,
                  isVisible: isVisible,
                );
                if (isEditing) {
                  await _mongoService.updateInfoPage(page.id, newPage);
                } else {
                  await _mongoService.addInfoPage(newPage);
                }
                Navigator.pop(context);
                _refreshPages();
                widget.onRefresh?.call();
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }
}
