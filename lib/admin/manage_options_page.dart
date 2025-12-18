import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageOptionsPage extends StatefulWidget {
  final String collectionName;

  const ManageOptionsPage({super.key, required this.collectionName});

  @override
  State<ManageOptionsPage> createState() => _ManageOptionsPageState();
}

class _ManageOptionsPageState extends State<ManageOptionsPage> {
  final MongoService _mongoService = MongoService();
  late Future<List<Option>> _optionsFuture;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _fetchOptions();
  }

  Future<List<Option>> _fetchOptions() {
    return _mongoService.getOptions(widget.collectionName);
  }

  void _refreshOptions() {
    setState(() {
      _optionsFuture = _fetchOptions();
    });
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _hasChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showOptionDialog(),
          backgroundColor: Colors.transparent,
          tooltip: 'Ajouter une option',
          child: Container(
            decoration: const BoxDecoration(
              gradient: buttonGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
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
                Expanded(child: _buildOptionsList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    const accentColor = Color(0xFF53c6fd);
    final title = 'Gérer: ${widget.collectionName.replaceAll("Options", "") }';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: accentColor, size: 28),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: accentColor)),
        ],
      ),
    );
  }

  Widget _buildOptionsList() {
    return FutureBuilder<List<Option>>(
      future: _optionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune option trouvée.', style: TextStyle(fontSize: 16, color: Colors.black54)));
        }

        final options = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return _buildListItemCard(
              title: option.name,
              subtitle: 'Prix: ${option.price.toStringAsFixed(2)} €',
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF53c6fd)),
                  onPressed: () => _showOptionDialog(option: option),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteOption(option.id),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListItemCard({
    required String title,
    String? subtitle,
    List<Widget>? actions,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ],
              ),
            ),
            if (actions != null) ...actions,
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOption(String optionId) async {
    try {
      await _mongoService.deleteOption(widget.collectionName, optionId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Option supprimée!'), backgroundColor: Colors.green));
      _refreshOptions();
      setState(() {
        _hasChanges = true;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showOptionDialog({Option? option}) async {
    final isEditing = option != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: option?.name);
    final priceController = TextEditingController(text: option?.price.toString() ?? '0.0');

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return Dialog(
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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(isEditing ? 'Modifier l\'Option' : 'Nouvelle Option', style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF53c6fd))),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: _buildInputDecoration(label: 'Nom de l\'option', icon: Icons.text_fields),
                    validator: (v) => (v == null || v.isEmpty) ? 'Le nom est requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: _buildInputDecoration(label: 'Prix', icon: Icons.euro_symbol),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Prix invalide' : null,
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
                          try {
                            final newName = nameController.text;
                            final newPrice = double.parse(priceController.text);
                            if (isEditing) {
                              await _mongoService.updateOption(widget.collectionName, option.id, newName, newPrice);
                            } else {
                              await _mongoService.addOption(widget.collectionName, newName, newPrice);
                            }
                            Navigator.of(dialogContext).pop();
                            _refreshOptions();
                            setState(() => _hasChanges = true);
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
}