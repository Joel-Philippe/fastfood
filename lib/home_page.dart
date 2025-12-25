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
  List<MenuItem> _allMenuItems = [];
  MenuCategory? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  late ConfettiController _confettiController;

  // Restaurant status state
  RestaurantSettings? _settings;
  bool _isRestaurantOpen = true;
  Duration? _timeUntilOpening;
  Duration? _timeUntilClosing;
  Timer? _statusTimer;
  Timer? _closingTimer;

  // WebSocket for real-time updates
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 300));
    _fetchData();
    _initWebSocket();
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
    _statusTimer?.cancel();
    _closingTimer?.cancel();
    _socketSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authService.getToken();
      _webSocketService.connect(token ?? '');

      _socketSubscription = _webSocketService.stream.listen((message) {
        if (!mounted) return;

        final type = message['type'] as String?;
        debugPrint('HomePage: Received WebSocket event of type: $type');

        const refreshEvents = [
          'SETTINGS_UPDATED',
          'CATEGORY_CREATED',
          'CATEGORY_UPDATED',
          'CATEGORY_DELETED',
          'MENU_ITEM_CREATED',
          'MENU_ITEM_UPDATED',
          'MENU_ITEM_DELETED',
        ];

        if (type != null && refreshEvents.contains(type)) {
          _fetchData();
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
      final results = await Future.wait<dynamic>([
        mongoService.getSettings(),
        mongoService.getCategories(),
      ]);

      _settings = results[0] as RestaurantSettings;
      final categories = results[1] as List<MenuCategory>;

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
        _allMenuItems = groupedItems.values.expand((items) => items).toList();
        
        if (_groupedItems.isNotEmpty) {
          if (_selectedCategory == null || !_groupedItems.containsKey(_selectedCategory)) {
             _selectedCategory = _groupedItems.keys.first;
          }
        }
        _isLoading = false;
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
    final dayKey = now.weekday.toString();
    final todayHours = _settings!.hours[dayKey];

    if (todayHours == null || !todayHours.isOpen) {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
        _timeUntilClosing = null;
        _closingTimer?.cancel();
      });
      return;
    }

    final openTimeParts = todayHours.openTime.split(':');
    final closeTimeParts = todayHours.closeTime.split(':');

    final openTime = DateTime(now.year, now.month, now.day, int.parse(openTimeParts[0]), int.parse(openTimeParts[1]));
    var closeTime = DateTime(now.year, now.month, now.day, int.parse(closeTimeParts[0]), int.parse(closeTimeParts[1]));

    if (closeTime.isBefore(openTime)) {
      closeTime = closeTime.add(const Duration(days: 1));
    }

    if (now.isAfter(openTime) && now.isBefore(closeTime)) {
      final timeToClose = closeTime.difference(now);
      const oneHour = Duration(hours: 1);

      setState(() {
        _isRestaurantOpen = true;
        _timeUntilOpening = null;
        if (timeToClose <= oneHour) {
          _timeUntilClosing = timeToClose;
          _startClosingTimer();
        } else {
          _timeUntilClosing = null;
          _closingTimer?.cancel();
        }
      });
    } else {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
        _timeUntilClosing = null;
        _closingTimer?.cancel();
      });
    }
  }

  void _startClosingTimer() {
    if (_closingTimer?.isActive ?? false) return;

    _closingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeUntilClosing == null || _timeUntilClosing! <= Duration.zero) {
        timer.cancel();
        _checkRestaurantStatus(); // Re-check status once timer ends
      } else {
        setState(() {
          _timeUntilClosing = _timeUntilClosing! - const Duration(seconds: 1);
        });
      }
    });
  }

  Duration _calculateTimeUntilNextOpening(DateTime now) {
    final todayIndex = now.weekday;

    for (int i = 0; i < 7; i++) {
      final dayIndex = (todayIndex - 1 + i) % 7 + 1;
      final dayKey = dayIndex.toString();
      final dayHours = _settings!.hours[dayKey];

      if (dayHours != null && dayHours.isOpen) {
        final openTimeParts = dayHours.openTime.split(':');
        var nextOpeningTime = DateTime(
          now.year,
          now.month,
          now.day + i,
          int.parse(openTimeParts[0]),
          int.parse(openTimeParts[1]),
        );

        if (i == 0 && now.isBefore(nextOpeningTime)) {
          return nextOpeningTime.difference(now);
        } else if (i > 0) {
          return nextOpeningTime.difference(now);
        }
      }
    }
    return const Duration(days: 99);
  }

  bool _shouldNavigateToCustomization(MenuItem item) {
    return item.category == 'menus' || item.optionTypes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: GradientText(
                    'Tacos Locos',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    gradient: const LinearGradient(colors: [Color(0xFFE63198), Color(0xFFFEC20B)]),
                  ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Color(0xFF18e9fe)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    ).then((_) {
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
              alignment: Alignment.bottomCenter,
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

  Widget _buildClosingSoonBanner() {
    if (_timeUntilClosing == null) {
      return const SizedBox.shrink();
    }

    final minutesLeft = _timeUntilClosing!.inMinutes;
    final secondsLeft = _timeUntilClosing!.inSeconds % 60;
    final timeString = '${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade700,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'Fermeture dans $timeString ! Dépêchez-vous !',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ).animate().slideIn(duration: 300.ms, begin: const Offset(0, -1)).then().shakeX(amount: 2);
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
    if (_allMenuItems.isEmpty) {
      return const Center(child: Text('Aucun article disponible.'));
    }

    final defaultAccentColor = Theme.of(context).colorScheme.primary;
    final Color selectedCategoryColor = _selectedCategory != null && _selectedCategory!.fontColor != null
        ? Color(int.parse(_selectedCategory!.fontColor!.substring(1, 7), radix: 16) + 0xFF000000)
        : defaultAccentColor;

    return Column(
      children: [
        _buildClosingSoonBanner(),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: _buildCategoryTabs(),
              ),
              Expanded(
                child: _buildMenuItemsList(selectedCategoryColor),
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
                });
              },
            ).animate().fadeIn(delay: (100 * index).ms),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemsList(Color selectedCategoryColor) {
    if (_selectedCategory == null) {
      return const Center(child: Text('Veuillez sélectionner une catégorie.'));
    }
    
    final items = _groupedItems[_selectedCategory] ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('Aucun article dans cette catégorie.'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return MenuItemCard(
          item: item,
          onAddItem: _onAddItem,
          index: index,
          cardTextColor: selectedCategoryColor,
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
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_cart, color: Color(0xFF18e9fe)),
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
