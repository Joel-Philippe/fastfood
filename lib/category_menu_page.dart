import 'dart:async';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/cart_bottom_sheet.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/menu_customization_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fast_food_app/widgets/menu_item_card.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

class CategoryMenuPage extends StatefulWidget {
  final MenuCategory category;
  final MongoService? mongoService; // Make it optional for testing

  const CategoryMenuPage({super.key, required this.category, this.mongoService});

  @override
  _CategoryMenuPageState createState() => _CategoryMenuPageState();
}

class _CategoryMenuPageState extends State<CategoryMenuPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // State management
  List<MenuItem>? _items;
  bool _isLoading = true;
  String? _error;

  // Services
  late final MongoService _mongoService;
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _mongoService = widget.mongoService ?? MongoService();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fetchItems();
    _initWebSocket();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _socketSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    // This check ensures we don't try to refetch while already fetching.
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final items = await _mongoService.getMenuItems(widget.category.type);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authService.getToken();
      _webSocketService.connect(token ?? ''); // Connect for broadcasts

      _socketSubscription = _webSocketService.stream.listen((message) {
        if (!mounted) return;

        final type = message['type'] as String?;
        debugPrint('CategoryMenuPage: Received WebSocket event of type: $type');

        const refreshEvents = [
          'MENU_ITEM_CREATED',
          'MENU_ITEM_UPDATED',
          'MENU_ITEM_DELETED',
        ];

        if (type != null && refreshEvents.contains(type)) {
          // Check if the change affects this specific category
          bool shouldRefresh = true;
          if (message['item'] != null && message['item']['category'] != null) {
            shouldRefresh = message['item']['category'] == widget.category.type;
          } else if (type == 'MENU_ITEM_DELETED') {
            // For deletion, we don't have the category info easily, so we refresh conservatively.
            // A better implementation would include the category in the delete event payload.
            shouldRefresh = true;
          }

          if (shouldRefresh) {
            _fetchItems();
          }
        }
      }, onError: (error) {
        debugPrint("CategoryMenuPage WebSocket Stream Error: $error");
      });
    } catch (e) {
      debugPrint("CategoryMenuPage Failed to initialize WebSocket: $e");
    }
  }

  bool _shouldNavigateToCustomization(MenuItem item) {
    return item.category == 'menus' || item.optionTypes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: GradientIcon(
            Icons.arrow_back,
            size: 24,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE63198),
                Color(0xFFFEC20B),
              ],
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GradientText(
          widget.category.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFE63198),
              Color(0xFFFEC20B),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: _buildFabCartButton(context),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_items == null || _items!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fastfood, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'Aucun article disponible pour ${widget.category.name} pour le moment !',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Veuillez en ajouter depuis le panneau d\'administration.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final itemsForCategory = _items!;

    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: itemsForCategory.length,
      itemBuilder: (context, index) {
        final item = itemsForCategory[index];
        final Color cardTextColor = widget.category.fontColor != null
            ? Color(int.parse(widget.category.fontColor!.substring(1, 7), radix: 16) + 0xFF000000)
            : Theme.of(context).primaryColor;

        return MenuItemCard(
          item: item,
          onAddItem: (ctx, menuItem, color) => _onAddItem(menuItem),
          index: index,
          cardTextColor: cardTextColor,
        );
      },
    );
  }

  Widget _buildFabCartButton(BuildContext context) {
    const fabGradient = LinearGradient(
      colors: [Color(0xFF53c6fd), Color(0xFF9c4dea)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: cart.itemCount > 0
              ? Container(
                  key: const ValueKey('CartFab'),
                  decoration: BoxDecoration(
                    gradient: fabGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'cart_fab_category',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CartBottomSheet(),
                      );
                    },
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.white),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return ScaleTransition(scale: animation, child: child);
                              },
                              child: Text(
                                '${cart.itemCount}',
                                key: ValueKey<int>(cart.itemCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('EmptyFab')),
        );
      },
    );
  }

  void _onAddItem(MenuItem item) {
    if (_shouldNavigateToCustomization(item)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuCustomizationPage(menuItem: item),
        ),
      );
    } else {
      Provider.of<CartProvider>(context, listen: false).addItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} ajouté au panier !')),
      );
      _animationController.forward(from: 0);
    }
  }
}