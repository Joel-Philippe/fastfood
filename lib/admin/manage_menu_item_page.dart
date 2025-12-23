import 'package:fast_food_app/app_config.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';

class ManageMenuItemPage extends StatefulWidget {
  final MenuItem? menuItem;

  const ManageMenuItemPage({super.key, this.menuItem});

  @override
  State<ManageMenuItemPage> createState() => _ManageMenuItemPageState();
}

class _ManageMenuItemPageState extends State<ManageMenuItemPage> {
  String _proxiedImageUrl(String url) {
    return '${AppConfig.baseUrl}/api/image-proxy?url=${Uri.encodeComponent(url)}';
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _removableIngredientsController = TextEditingController();

  String? _selectedCategory;
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _existingImageUrl;

  List<MenuCategory> _availableCategories = [];
  late Future<List<String>> _optionTypesFuture;
  final Set<String> _selectedOptionTypes = {};

  final MongoService _mongoService = MongoService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _optionTypesFuture = _mongoService.getOptionTypes();
      final categories = await _mongoService.getCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          if (widget.menuItem != null) {
            _nameController.text = widget.menuItem!.name;
            _descriptionController.text = widget.menuItem!.description ?? '';
            _priceController.text = widget.menuItem!.price.toString();
            _selectedCategory = widget.menuItem!.category;
            _existingImageUrl = widget.menuItem!.imageUrl;
            _removableIngredientsController.text = widget.menuItem!.removableIngredients.join(', ');
            _selectedOptionTypes.addAll(widget.menuItem!.optionTypes);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _removableIngredientsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image trop lourde (max 10Mo).')));
        return;
      }
      setState(() {
        if (kIsWeb) {
          _imageBytes = bytes;
          _imageFile = null;
        } else {
          _imageFile = File(pickedFile.path);
          _imageBytes = null;
        }
        _existingImageUrl = null;
      });
    }
  }

  Future<void> _saveMenuItem() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final newMenuItem = MenuItem(
        id: widget.menuItem?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        imageUrl: _existingImageUrl,
        category: _selectedCategory!,
        optionTypes: _selectedOptionTypes.toList(),
        removableIngredients: _removableIngredientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );

      try {
        if (widget.menuItem == null) {
          await _mongoService.addMenuItem(newMenuItem, imageFile: _imageFile, imageBytes: _imageBytes, fileName: _nameController.text);
        } else {
          await _mongoService.updateMenuItem(newMenuItem, imageFile: _imageFile, imageBytes: _imageBytes, fileName: _nameController.text);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Article ${widget.menuItem == null ? 'ajouté' : 'mis à jour'}!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: _isLoading && _availableCategories.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)))
                    : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    const accentColor = Color(0xFF53c6fd);
    final title = widget.menuItem == null ? 'Ajouter un Article' : 'Modifier l\'Article';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: accentColor, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: accentColor)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    const accentColor = Color(0xFF53c6fd);
    const buttonGradient = LinearGradient(colors: [Color(0xFF9c4dea), Color(0xFFff80b1)]);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildImagePicker(),
          const SizedBox(height: 24),
          TextFormField(controller: _nameController, decoration: _buildInputDecoration(label: 'Nom', icon: Icons.fastfood_outlined), validator: (v) => v!.isEmpty ? 'Nom requis' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _descriptionController, decoration: _buildInputDecoration(label: 'Description', icon: Icons.description_outlined), maxLines: 3),
          const SizedBox(height: 16),
          TextFormField(controller: _priceController, decoration: _buildInputDecoration(label: 'Prix', icon: Icons.euro_symbol), keyboardType: TextInputType.number, validator: (v) => double.tryParse(v!) == null ? 'Prix invalide' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _removableIngredientsController, decoration: _buildInputDecoration(label: 'Ingrédients à retirer (séparés par ,)', icon: Icons.remove_circle_outline)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: _buildInputDecoration(label: 'Catégorie', icon: Icons.category_outlined),
            items: _availableCategories.map((c) => DropdownMenuItem(value: c.type, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
            validator: (v) => v == null ? 'Catégorie requise' : null,
          ),
          const SizedBox(height: 24),
          const Text('Types d\'options applicables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          _buildDynamicOptionsSelector(),
          const SizedBox(height: 32),
          _isLoading
            ? const Center(child: CircularProgressIndicator(color: accentColor))
            : GestureDetector(
                onTap: _saveMenuItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(gradient: buttonGradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: buttonGradient.colors.first.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: const Center(child: Text('Sauvegarder', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
        ],
      ),
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

  Widget _buildImagePicker() {
    Widget content;
    if (_imageBytes != null) {
      content = ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(_imageBytes!, fit: BoxFit.cover));
    } else if (_imageFile != null) {
      content = ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(_imageFile!, fit: BoxFit.cover));
    } else if (_existingImageUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          _proxiedImageUrl(_existingImageUrl!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      );
    } else {
      content = const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, size: 40, color: Colors.grey), Text('Choisir une image', style: TextStyle(color: Colors.grey))]));
    }
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: content,
      ),
    );
  }

  Widget _buildDynamicOptionsSelector() {
    const accentColor = Color(0xFF53c6fd);
    return FutureBuilder<List<String>>(
      future: _optionTypesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: accentColor)));
        final allOptionTypes = snapshot.data!;
        return Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: allOptionTypes.map((type) {
            final isSelected = _selectedOptionTypes.contains(type);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedOptionTypes.remove(type);
                  } else {
                    _selectedOptionTypes.add(type);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? accentColor : Colors.grey[300]!, width: 1.5),
                ),
                child: Text(
                  type.replaceAll('Options', ''),
                  style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}