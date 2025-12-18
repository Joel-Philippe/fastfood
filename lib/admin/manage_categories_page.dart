import 'dart:io';
import 'dart:typed_data';
import 'package:fast_food_app/main.dart';
import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageCategoriesPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const ManageCategoriesPage({super.key, this.onRefresh});

  @override
  _ManageCategoriesPageState createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  String _proxiedImageUrl(String url) {
    return '$baseUrl/api/image-proxy?url=${Uri.encodeComponent(url)}';
  }

  final MongoService _mongoService = MongoService();
  late Future<List<MenuCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshCategories();
  }

  void _refreshCategories() {
    setState(() {
      _categoriesFuture = _mongoService.getCategories();
    });
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
      backgroundColor: Colors.transparent, // Part of the tab view
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showCategoryDialog(context),
        backgroundColor: Colors.transparent,
        tooltip: 'Ajouter une catégorie',
        child: Container(
          decoration: const BoxDecoration(
            gradient: buttonGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<MenuCategory>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune catégorie trouvée.', style: TextStyle(fontSize: 16, color: Colors.black54)));
          }

          final categories = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(category, accentColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(MenuCategory category, Color accentColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: (category.backgroundImageUrl != null && category.backgroundImageUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(_proxiedImageUrl(category.backgroundImageUrl!)),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: (category.backgroundImageUrl == null || category.backgroundImageUrl!.isEmpty)
                    ? Colors.grey.shade200
                    : null,
              ),
              child: (category.backgroundImageUrl == null || category.backgroundImageUrl!.isEmpty)
                  ? Icon(Icons.category, color: Colors.grey.shade400)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 4),
                  Text('Type: ${category.type}', style: const TextStyle(color: Colors.black54), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: accentColor),
                  onPressed: () => _showCategoryDialog(context, category: category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteCategory(category.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(String id) async {
    try {
      await _mongoService.deleteCategory(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catégorie supprimée!'), backgroundColor: Colors.green),
      );
      _refreshCategories();
      widget.onRefresh?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCategoryDialog(BuildContext pageContext, {MenuCategory? category}) {
    final isEditing = category != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name);
    final typeController = TextEditingController(text: category?.type);

    Color fontColor = category?.fontColorAsColor ?? Colors.black;
    Color bgColor = category?.backgroundColorAsColor ?? Colors.grey[200]!;
    XFile? imageFile;

    showDialog(
      context: pageContext,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogContent = Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfcf1f1), Color(0xFFfffcdd)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(isEditing ? 'Modifier la Catégorie' : 'Nouvelle Catégorie', style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF53c6fd))),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: nameController,
                          decoration: _buildInputDecoration(label: 'Nom (Ex: Nos Wraps)', icon: Icons.text_fields),
                          validator: (v) => (v == null || v.isEmpty) ? 'Le nom est requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: typeController,
                          decoration: _buildInputDecoration(label: 'Type (Ex: wraps)', icon: Icons.code),
                          validator: (v) => (v == null || v.isEmpty) ? 'Le type est requis' : null,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () async {
                            final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) setDialogState(() => imageFile = pickedFile);
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300)
                            ),
                            child: _buildImagePreview(imageFile, category),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildColorPicker(context, 'Police', fontColor, (color) => setDialogState(() => fontColor = color)),
                            _buildColorPicker(context, 'Fond', bgColor, (color) => setDialogState(() => bgColor = color)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler', style: TextStyle(color: Colors.black54))),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF53c6fd)),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final fontHex = '#${fontColor.value.toRadixString(16).substring(2)}';
                                final bgHex = '#${bgColor.value.toRadixString(16).substring(2)}';
                                try {
                                  if (isEditing) {
                                    await _mongoService.updateCategory(category.id, nameController.text, typeController.text, fontColor: fontHex, backgroundColor: bgHex);
                                    if (imageFile != null) {
                                      await _mongoService.updateCategoryImage(categoryId: category.id, imageFile: imageFile!);
                                    }
                                  } else {
                                    await _mongoService.addCategory(name: nameController.text, type: typeController.text, fontColor: fontHex, backgroundColor: bgHex, imageFile: imageFile);
                                  }
                                  Navigator.of(dialogContext).pop();
                                  _refreshCategories();
                                  widget.onRefresh?.call();
                                } catch (e) {
                                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                }
                              },
                              child: Text(isEditing ? 'Sauvegarder' : 'Ajouter', style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            return dialogContent;
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    const accentColor = Color(0xFF53c6fd);
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(icon, color: accentColor),
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentColor, width: 2)),
    );
  }

  Widget _buildImagePreview(XFile? imageFile, MenuCategory? category) {
    if (imageFile != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(File(imageFile.path), fit: BoxFit.cover));
    }
    if (category?.backgroundImageUrl != null && category!.backgroundImageUrl!.isNotEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.network(_proxiedImageUrl(category.backgroundImageUrl!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))));
    }
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, size: 40, color: Colors.grey), Text('Sélectionner une image', style: TextStyle(color: Colors.grey))]));
  }

  Widget _buildColorPicker(BuildContext context, String title, Color currentColor, Function(Color) onColorChanged) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Choisir une couleur pour $title'),
                content: SingleChildScrollView(child: ColorPicker(pickerColor: currentColor, onColorChanged: onColorChanged)),
                actions: [ElevatedButton(child: const Text('Valider'), onPressed: () => Navigator.of(context).pop())],
              ),
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            ),
          ),
        ),
      ],
    );
  }
}
