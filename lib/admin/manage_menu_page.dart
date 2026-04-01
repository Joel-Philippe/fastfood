import 'dart:async';
import 'package:fast_food_app/app_config.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/admin/manage_menu_item_page.dart';
import 'package:fast_food_app/admin/manage_options_page.dart';
import 'package:fast_food_app/admin/manage_categories_page.dart';
import 'package:fast_food_app/admin/manage_hours_page.dart';
import 'package:fast_food_app/admin/manage_info_pages.dart';
import 'package:fast_food_app/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageMenuPage extends StatefulWidget {
  const ManageMenuPage({super.key});

  @override
  State<ManageMenuPage> createState() => _ManageMenuPageState();
}

class _ManageMenuPageState extends State<ManageMenuPage> with SingleTickerProviderStateMixin {
  final MongoService _mongoService = MongoService();
  late TabController _tabController;
  
  // State variables
  List<MenuItem>? _menuItems;
  List<String>? _optionTypes;
  bool _isLoading = true;
  String? _error;
  
  // WillPopScope state
  bool _hasChanges = false;

  // WebSocket service
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
    _initWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _socketSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!_isLoading && mounted) {
      setState(() { _isLoading = true; });
    }
    try {
      final results = await Future.wait([
        _mongoService.getMenuItemsForAdmin(),
        _mongoService.getOptionTypes(),
      ]);
      if (mounted) {
        setState(() {
          _menuItems = results[0] as List<MenuItem>;
          _optionTypes = results[1] as List<String>;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      _webSocketService.connect(token);

      _socketSubscription = _webSocketService.stream.listen((message) {
        if (!mounted) return;
        final type = message['type'] as String?;
        
        const refreshEvents = [
          'CATEGORY_CREATED', 'CATEGORY_UPDATED', 'CATEGORY_DELETED',
          'MENU_ITEM_CREATED', 'MENU_ITEM_UPDATED', 'MENU_ITEM_DELETED',
          'OPTION_CREATED', 'OPTION_UPDATED', 'OPTION_DELETED'
        ];

        if (type != null && refreshEvents.contains(type)) {
          _hasChanges = true;
          _fetchData();
        }
      });
    } catch (e) {
      debugPrint("ManageMenuPage failed to init WebSocket: $e");
    }
  }

  void _handleRefresh() {
    _hasChanges = true;
    _fetchData();
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _hasChanges);
    return false;
  }
  
  String _proxiedImageUrl(String url) {
    return '${AppConfig.baseUrl}/api/image-proxy?url=${Uri.encodeComponent(url)}';
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                heroTag: null,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageMenuItemPage()),
                  );
                },
                backgroundColor: Colors.transparent,
                tooltip: 'Ajouter un article',
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: buttonGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              )
            : null,
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text('Gérer le Menu', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: accentColor),
                    onPressed: () => Navigator.pop(context, _hasChanges),
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : const Color(0xFFfcf1f1).withOpacity(0.8),
                  floating: true,
                  pinned: true,
                  snap: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: accentColor,
                    unselectedLabelColor: isDark ? Colors.white38 : Colors.black54,
                    indicatorColor: accentColor,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Articles'),
                      Tab(text: 'Catégories'),
                      Tab(text: 'Options'),
                      Tab(text: 'Horaires'),
                      Tab(text: 'Pages d\'info'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMenuItemsTab(),
                ManageCategoriesPage(onRefresh: _handleRefresh),
                _buildOptionsTab(),
                ManageHoursPage(onRefresh: _handleRefresh),
                ManageInfoPages(onRefresh: _handleRefresh),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)));
    }
    if (_error != null) {
      return Center(child: Text(_error ?? 'Une erreur est survenue.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }
    if (_menuItems == null || _menuItems!.isEmpty) {
      return Center(child: Text('Aucun article de menu.', style: TextStyle(fontSize: 16, color: isDark ? Colors.white38 : Colors.black54)));
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _menuItems!.length,
          itemBuilder: (context, index) {
            final item = _menuItems![index];
            return _buildListItemCard(
              title: item.name,
              subtitle: '${item.price.toStringAsFixed(2)} €',
              leading:
                  item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                        _proxiedImageUrl(item.imageUrl!),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      ),
                        )
                      : null,
              actions: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF53c6fd)),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageMenuItemPage(menuItem: item)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      await _mongoService.deleteMenuItem(item.id);
                    },
                  ),
                ])
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOptionsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)));
    }
    if (_error != null) {
      return Center(child: Text(_error ?? 'Une erreur est survenue.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }
    if (_optionTypes == null || _optionTypes!.isEmpty) {
      return Center(child: Text('Aucun type d\'option trouvé.', style: TextStyle(fontSize: 16, color: isDark ? Colors.white38 : Colors.black54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _optionTypes!.length + 1,
      itemBuilder: (context, index) {
        if (index == _optionTypes!.length) {
          return _buildListItemCard(
            title: 'Ajouter un type d\'option',
            onTap: () => _showAddCustomOptionTypeDialog(context),
            actions: [Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add_circle_outline, color: Color(0xFF53c6fd))])],
          );
        }
        final typeName = _optionTypes![index];
        return _buildListItemCard(
          title: 'Gérer: ${typeName.replaceAll('Options', '')}',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ManageOptionsPage(collectionName: typeName)),
            );
          },
          actions: [Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.arrow_forward_ios, color: Color(0xFF53c6fd))])],
        );
      },
    );
  }
  
  Widget _buildListItemCard({
    required String title,
    String? subtitle,
    Widget? leading,
    List<Widget>? actions,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                  ],
                ),
              ),
              if (actions != null) Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomOptionTypeDialog(BuildContext context) {
    final TextEditingController typeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                    : [const Color(0xFFfcf1f1), const Color(0xFFfffcdd)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Nouveau Type d\'Option', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: typeController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Nom du type d\'option',
                      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                      hintText: 'Les espaces seront remplacés par des tirets',
                      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF53c6fd))),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Le nom est requis' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('Annuler', style: TextStyle(color: isDark ? Colors.white38 : Colors.black54)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF53c6fd)),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final sanitizedTypeName = typeController.text.toLowerCase().replaceAll(' ', '-');
                            Navigator.of(dialogContext).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ManageOptionsPage(collectionName: sanitizedTypeName)),
                            );
                          }
                        },
                        child: const Text('Créer et Gérer', style: TextStyle(color: Colors.white)),
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
}
