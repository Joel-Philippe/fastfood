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
import 'package:fast_food_app/services/websocket_service.dart';

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

  List<InfoPage> _infoPages = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 300));
    _fetchData();
    _fetchInfoPages();
    _initWebSocket();
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
        const refreshEvents = [
          'SETTINGS_UPDATED', 'CATEGORY_CREATED', 'CATEGORY_UPDATED', 'CATEGORY_DELETED',
          'MENU_ITEM_CREATED', 'MENU_ITEM_UPDATED', 'MENU_ITEM_DELETED',
          'INFO_PAGE_CREATED', 'INFO_PAGE_UPDATED', 'INFO_PAGE_DELETED',
        ];
        if (type != null && refreshEvents.contains(type)) {
          _fetchData();
          _fetchInfoPages();
        }
      });
    } catch (e) {
      debugPrint("HomePage Failed to initialize WebSocket: $e");
    }
  }

  Future<void> _fetchInfoPages() async {
    try {
      final pages = await (widget.mongoService ?? MongoService()).getInfoPages();
      if (mounted) setState(() => _infoPages = pages);
    } catch (e) {
      debugPrint("Error fetching info pages: $e");
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
          if (items.isNotEmpty) groupedItems[category] = items;
        }
      }
      if (!mounted) return;
      setState(() {
        _groupedItems = groupedItems;
        _allMenuItems = groupedItems.values.expand((items) => items).toList();
        if (_groupedItems.isNotEmpty && (_selectedCategory == null || !_groupedItems.containsKey(_selectedCategory))) {
          _selectedCategory = _groupedItems.keys.first;
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
    final todayHours = _settings!.hours[now.weekday.toString()];
    if (todayHours == null || !todayHours.isOpen) {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
        _timeUntilClosing = null;
      });
      return;
    }
    final openParts = todayHours.openTime.split(':');
    final closeParts = todayHours.closeTime.split(':');
    final openTime = DateTime(now.year, now.month, now.day, int.parse(openParts[0]), int.parse(openParts[1]));
    var closeTime = DateTime(now.year, now.month, now.day, int.parse(closeParts[0]), int.parse(closeParts[1]));
    if (closeTime.isBefore(openTime)) closeTime = closeTime.add(const Duration(days: 1));
    if (now.isAfter(openTime) && now.isBefore(closeTime)) {
      final timeToClose = closeTime.difference(now);
      setState(() {
        _isRestaurantOpen = true;
        _timeUntilOpening = null;
        if (timeToClose <= const Duration(hours: 1)) {
          _timeUntilClosing = timeToClose;
          _startClosingTimer();
        }
      });
    } else {
      setState(() {
        _isRestaurantOpen = false;
        _timeUntilOpening = _calculateTimeUntilNextOpening(now);
      });
    }
  }

  void _startClosingTimer() {
    if (_closingTimer?.isActive ?? false) return;
    _closingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeUntilClosing == null || _timeUntilClosing! <= Duration.zero) {
        timer.cancel();
        _checkRestaurantStatus();
      } else {
        setState(() => _timeUntilClosing = _timeUntilClosing! - const Duration(seconds: 1));
      }
    });
  }

  Duration _calculateTimeUntilNextOpening(DateTime now) {
    for (int i = 0; i < 7; i++) {
      final dayIndex = (now.weekday - 1 + i) % 7 + 1;
      final dayHours = _settings!.hours[dayIndex.toString()];
      if (dayHours != null && dayHours.isOpen) {
        final openParts = dayHours.openTime.split(':');
        var nextOpen = DateTime(now.year, now.month, now.day + i, int.parse(openParts[0]), int.parse(openParts[1]));
        if (i == 0 && now.isBefore(nextOpen)) return nextOpen.difference(now);
        if (i > 0) return nextOpen.difference(now);
      }
    }
    return const Duration(days: 99);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : Colors.white),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/five-minutes-logo.png', height: 40),
              ),
              centerTitle: true,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Color(0xFF18e9fe)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) {
                    setState(() => _isLoading = true);
                    _fetchData();
                  }),
                ),
              ],
              bottom: _infoPages.isNotEmpty ? PreferredSize(preferredSize: const Size.fromHeight(50), child: _buildInfoPagesMenu()) : null,
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

  Widget _buildInfoPagesMenu() {
    if (_infoPages.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _infoPages.length,
        itemBuilder: (context, index) {
          final page = _infoPages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _showInfoPage(page),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(_getIconData(page.icon), size: 16, color: const Color(0xFF53c6fd)),
                    const SizedBox(width: 6),
                    Text(page.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInfoPage(InfoPage page) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoPageViewer(page: page),
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

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (!_isRestaurantOpen && _timeUntilOpening != null) return RestaurantClosedWidget(timeUntilOpening: _timeUntilOpening!);
    if (_allMenuItems.isEmpty) return const Center(child: Text('Aucun article disponible.'));

    final Color selectedColor = _selectedCategory != null && _selectedCategory!.fontColor != null
        ? Color(int.parse(_selectedCategory!.fontColor!.substring(1, 7), radix: 16) + 0xFF000000)
        : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        if (_timeUntilClosing != null) _buildClosingSoonBanner(),
        Expanded(child: Row(children: [
          SizedBox(width: 100, child: _buildCategoryTabs()),
          Expanded(child: _buildMenuItemsList(selectedColor)),
        ])),
      ],
    );
  }

  Widget _buildClosingSoonBanner() {
    final minutes = _timeUntilClosing!.inMinutes;
    final seconds = _timeUntilClosing!.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.amber.shade700,
      child: Center(child: Text('Fermeture dans ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} !', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = _groupedItems.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CategoryCardWidget(
            category: cat,
            isSelected: cat == _selectedCategory,
            onTap: (c) => setState(() => _selectedCategory = c),
          ).animate().fadeIn(delay: (100 * index).ms),
        );
      },
    );
  }

  Widget _buildMenuItemsList(Color selectedColor) {
    if (_selectedCategory == null) return const SizedBox.shrink();
    final items = _groupedItems[_selectedCategory] ?? [];
    return LayoutBuilder(builder: (context, constraints) {
      int cols = 1;
      if (constraints.maxWidth > 1200) cols = 4;
      else if (constraints.maxWidth > 900) cols = 3;
      else if (constraints.maxWidth > 600) cols = 2;
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85),
        itemCount: items.length,
        itemBuilder: (context, index) => MenuItemCard(item: items[index], onAddItem: _onAddItem, index: index, cardTextColor: selectedColor),
      );
    });
  }

  void _onAddItem(BuildContext context, MenuItem item, Color confettiColor) {
    _confettiController.play();
    if (item.category == 'menus' || item.optionTypes.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MenuCustomizationPage(menuItem: item)));
    } else {
      Provider.of<CartProvider>(context, listen: false).addItem(item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
        content: GradientText('${item.name} ajouté !', style: const TextStyle(fontSize: 14), gradient: const LinearGradient(colors: [Color(0xFFE05601), Color(0xFFF87E12)])),
      ));
    }
  }

  Widget _buildFabCartButton(BuildContext context) {
    return Consumer<CartProvider>(builder: (context, cart, child) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: cart.itemCount > 0 ? FloatingActionButton(
          heroTag: 'cart_fab',
          onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const CartBottomSheet()),
          backgroundColor: const Color(0xFF53c6fd),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // Permet au badge de dépasser sans être coupé
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
              if (cart.itemCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF53c6fd), width: 1.5), // Ajout d'une bordure pour mieux le détacher
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ) : const SizedBox.shrink(),
      );
    });
  }
}

class _InfoPageViewer extends StatelessWidget {
  final InfoPage page;
  const _InfoPageViewer({required this.page});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Center(child: Container(constraints: const BoxConstraints(maxWidth: 800), child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Center(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF53c6fd).withOpacity(0.1), shape: BoxShape.circle), child: Icon(_getIconData(page.icon), color: const Color(0xFF53c6fd), size: 48))),
            const SizedBox(height: 24),
            Text(page.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(child: Container(width: 60, height: 3, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF53c6fd), Color(0xFF9c4dea)]), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 40),
            Text(page.content, style: TextStyle(fontSize: 18, height: 1.8, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87)),
            const SizedBox(height: 60),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer la lecture', style: TextStyle(color: Color(0xFF53c6fd), fontWeight: FontWeight.bold)))),
          ],
        ))),
      ),
    );
  }
  IconData _getIconData(String n) {
    switch (n) { case 'restaurant': return Icons.restaurant; case 'delivery': return Icons.delivery_dining; case 'contact': return Icons.contact_support; case 'history': return Icons.history; case 'star': return Icons.star; default: return Icons.info; }
  }
}
