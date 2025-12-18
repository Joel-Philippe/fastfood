import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/cart_bottom_sheet.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/menu_customization_page.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fast_food_app/widgets/menu_item_card.dart';
import 'package:fast_food_app/widgets/category_card_widget.dart';
import 'package:fast_food_app/profile_page.dart';
import 'package:fast_food_app/widgets/restaurant_closed_widget.dart';
import 'package:fast_food_app/services/websocket_service.dart'; // Import WebSocketService

class HomePage extends StatefulWidget {
  final MongoService? mongoService;
  final AuthService? authService;

  const HomePage({super.key, this.mongoService, this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<MenuCategory, List<MenuItem>> _groupedItems = {};
  List<MenuItem> _allMenuItems = []; // New: For global search
  MenuCategory? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  late ConfettiController _confettiController;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _filteredMenuItems = [];

  // Restaurant status state
  RestaurantSettings? _settings;
  bool _isRestaurantOpen = true;
  Duration? _timeUntilOpening;
  Timer? _statusTimer;

  // WebSocket for real-time updates
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService(); // Use local authService
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 300));
    _searchController.addListener(_filterMenuItems);
    _fetchData();
    _initWebSocket(); // Initialize WebSocket
    // Periodically check the restaurant status
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_settings != null) {
        _checkRestaurantStatus();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.removeListener(_filterMenuItems);
    _searchController.dispose();
    _statusTimer?.cancel();
    _socketSubscription?.cancel(); // Cancel WebSocket subscription
    _webSocketService.disconnect(); // Disconnect WebSocket
    super.dispose();
  }

  void _filterMenuItems() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        // If query is empty, show items from the selected category
        if (_selectedCategory != null && _groupedItems.containsKey(_selectedCategory)) {
          _filteredMenuItems = _groupedItems[_selectedCategory]!;
        } else {
          _filteredMenuItems = [];
        }
      } else {
        // If query is not empty, search across all items
        _filteredMenuItems = _allMenuItems.where((item) {
          final nameMatch = item.name.toLowerCase().contains(query);
          final descriptionMatch = item.description?.toLowerCase().contains(query) ?? false;
          // Optionally, you could also match the category name
          // final categoryMatch = item.category.toLowerCase().contains(query);
          return nameMatch || descriptionMatch;
        }).toList();
      }
    });
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('HomePage: No token found, cannot connect to WebSocket.');
        // This is fine as the homepage is public, but we still want to listen for broadcast updates
        // so we connect without a token. The backend broadcastToAllUsers doesn't check token.
        _webSocketService.connect(''); // Connect with empty token for broadcasts
      } else {
        _webSocketService.connect(token);
      }

      _socketSubscription = _webSocketService.stream.listen((message) {
        if (message['type'] == 'MENU_UPDATE' || message['type'] == 'SETTINGS_UPDATE') {
          debugPrint('HomePage: Received ${message['type']} update, refreshing data.');
          _fetchData(); // Re-fetch all data to update UI
        }
      }, onError: (error) {
        debugPrint("HomePage WebSocket Stream Error: $error");
      });
    } catch (e) {
      debugPrint("HomePage Failed to initialize WebSocket: $e");
    }
  }

  Future<void> _fetchData() async {
    try {
      final mongoService = widget.mongoService ?? MongoService();
      // Fetch settings and menu data in parallel
      final results = await Future.wait<dynamic>([
        mongoService.getSettings(),
        mongoService.getCategories(),
      ]);

      _settings = results[0] as RestaurantSettings;
      final categories = results[1] as List<MenuCategory>;

      // Check status before fetching menu items
      _checkRestaurantStatus();

      final Map<MenuCategory, List<MenuItem>> groupedItems = {};
      if (_isRestaurantOpen) {
        for (final category in categories) {
          final items = await mongoService.getMenuItems(category.type);
          if (items.isNotEmpty) {
            groupedItems[category] = items;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _groupedItems = groupedItems;
        _allMenuItems = groupedItems.values.expand((items) => items).toList(); // Populate all items
        
        if (_groupedItems.isNotEmpty) {
          // If a category is already selected, keep it. Otherwise, select the first one.
          if (_selectedCategory == null || !_groupedItems.containsKey(_selectedCategory)) {
             _selectedCategory = _groupedItems.keys.first;
          }
        }
        _isLoading = false;
        _filterMenuItems(); // This will now correctly show the selected category's items
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _checkRestaurantStatus() {
    if (_settings == null) return;

    final now = DateTime.now();
    // Use the numeric weekday (1=Monday, 7=Sunday) as the key, which is language-independent.
    final dayKey = now.weekday.toString();
    final todayHours = _settings!.hours[dayKey];

    if (todayHours == null || !todayHours.isOpen) {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
      });
      return;
    }

    final openTimeParts = todayHours.openTime.split(':');
    final closeTimeParts = todayHours.closeTime.split(':');

    final openTime = DateTime(now.year, now.month, now.day, int.parse(openTimeParts[0]), int.parse(openTimeParts[1]));
    var closeTime = DateTime(now.year, now.month, now.day, int.parse(closeTimeParts[0]), int.parse(closeTimeParts[1]));

    // Handle overnight closing times (e.g., open 22:00, close 02:00)
    if (closeTime.isBefore(openTime)) {
      closeTime = closeTime.add(const Duration(days: 1));
    }

    if (now.isAfter(openTime) && now.isBefore(closeTime)) {
      setState(() {
        _isRestaurantOpen = true;
        _timeUntilOpening = null;
      });
    } else {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
      });
    }
  }

  Duration _calculateTimeUntilNextOpening(DateTime now) {
    final todayIndex = now.weekday; // 1 for Monday, 7 for Sunday

    for (int i = 0; i < 7; i++) {
      // Start check from today
      final dayIndex = (todayIndex - 1 + i) % 7 + 1;
      final dayKey = dayIndex.toString();
      final dayHours = _settings!.hours[dayKey];

      if (dayHours != null && dayHours.isOpen) {
        final openTimeParts = dayHours.openTime.split(':');
        var nextOpeningTime = DateTime(
          now.year,
          now.month,
          now.day + i, // Add the offset 'i' to get the correct future date
          int.parse(openTimeParts[0]),
          int.parse(openTimeParts[1]),
        );

        // If we are checking today (i=0) and the opening time is still in the future
        if (i == 0 && now.isBefore(nextOpeningTime)) {
          return nextOpeningTime.difference(now);
        }
        // If we are checking a future day (i>0)
        else if (i > 0) {
          return nextOpeningTime.difference(now);
        }
      }
    }
    // If no opening days are set, return a very long duration
    return const Duration(days: 99);
  }

  bool _shouldNavigateToCustomization(MenuItem item) {
    // An item needs customization if it's a 'menu' or has any option types associated with it.
    return item.category == 'menus' || item.optionTypes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final authServiceInstance = widget.authService ?? AuthService();

    // Determine the color for the search bar based on the selected category's fontColor
    final defaultAccentColor = Theme.of(context).colorScheme.primary;
    final Color searchBarColor = _selectedCategory != null && _selectedCategory!.fontColor != null
        ? Color(int.parse(_selectedCategory!.fontColor!.substring(1, 7), radix: 16) + 0xFF000000)
        : defaultAccentColor;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFEF1E0), Color(0xFFF8EDE9)],
        ),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Scaffold(
            backgroundColor: Colors.transparent, // Make scaffold transparent
            appBar: AppBar(
              title: Row(
                children: [
                  GradientText(
                    'Tacos Locos',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    gradient: const LinearGradient(colors: [Color(0xFFE63198), Color(0xFFFEC20B)]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: searchBarColor),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un article...',
                          hintStyle: TextStyle(color: searchBarColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.search, color: searchBarColor, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.8),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    ).then((_) {
                      // After returning from profile, force a refresh.
                      setState(() {
                        _isLoading = true;
                      });
                      _fetchData();
                    });
                  },
                ),
              ],
            ),
            body: _buildBody(),
            floatingActionButton: _isRestaurantOpen ? _buildFabCartButton(context) : null,
          ),
          if (_isRestaurantOpen)
            Align(
              alignment: Alignment.bottomCenter, // Moved to avoid FAB
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: -pi / 2,
                  blastDirectionality: BlastDirectionality.directional,
                  emissionFrequency: 0.05,
                  numberOfParticles: 10,
                  gravity: 0.2,
                  shouldLoop: false,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (!_isRestaurantOpen && _timeUntilOpening != null) {
      return RestaurantClosedWidget(timeUntilOpening: _timeUntilOpening!);
    }
    if (_allMenuItems.isEmpty) { // Check all items instead of grouped items
      return const Center(child: Text('Aucun article disponible.'));
    }

    // Determine the color for the menu item cards based on the selected category's fontColor
    final defaultAccentColor = Theme.of(context).colorScheme.primary; // A fallback accent color
    final Color selectedCategoryColor = _selectedCategory != null && _selectedCategory!.fontColor != null
        ? Color(int.parse(_selectedCategory!.fontColor!.substring(1, 7), radix: 16) + 0xFF000000)
        : defaultAccentColor; // Fallback to primary accent color

    return Column(
      children: [
        // The search bar has been moved to the AppBar.
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 100, // Adjusted width for the category sidebar
                child: _buildCategoryTabs(),
              ),
              Expanded(
                child: _buildMenuItemsList(selectedCategoryColor), // Pass the color
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    final categories = _groupedItems.keys.toList();
    return ShaderMask(
      shaderCallback: (Rect rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: const [0.0, 0.1, 0.9, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: CategoryCardWidget(
              category: category,
              isSelected: isSelected,
              onTap: (selectedCategory) {
                setState(() {
                  _selectedCategory = selectedCategory;
                  _searchController.clear(); // Clear search on category change
                  _filterMenuItems();
                });
              },
            ).animate().fadeIn(delay: (100 * index).ms),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemsList(Color selectedCategoryColor) { // Accept selectedCategoryColor as parameter
    if (_selectedCategory == null) {
      return const Center(child: Text('Veuillez sélectionner une catégorie.'));
    }

    if (_filteredMenuItems.isEmpty) {
      return const Center(child: Text('Aucun résultat trouvé.'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9, // Adjusted for new card layout
      ),
      itemCount: _filteredMenuItems.length,
      itemBuilder: (context, index) {
        final item = _filteredMenuItems[index];
        return MenuItemCard(
          item: item,
          onAddItem: _onAddItem,
          index: index,
          cardTextColor: selectedCategoryColor, // Pass the selected category's color
        );
      },
    );
  }

  void _onAddItem(BuildContext context, MenuItem item, Color confettiColor) {
    _confettiController.play();
    if (_shouldNavigateToCustomization(item)) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MenuCustomizationPage(menuItem: item)));
    } else {
      Provider.of<CartProvider>(context, listen: false).addItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: GradientText(
            '${item.name} ajouté au panier !',
            style: const TextStyle(fontSize: 14),
            gradient: const LinearGradient(colors: [Color(0xFFE05601), Color(0xFFF87E12)]),
          ),
        ),
      );
    }
  }

  Widget _buildFabCartButton(BuildContext context) {
    const fabGradient = LinearGradient(
      colors: [Color(0xFF53c6fd), Color(0xFF9c4dea)], // A new, "sober" gradient
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
                    heroTag: 'cart_fab', // Unique heroTag
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
                      clipBehavior: Clip.none, // Allow badge to overflow
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

}
