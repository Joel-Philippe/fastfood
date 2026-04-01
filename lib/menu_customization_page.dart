import 'package:fast_food_app/app_config.dart';
import 'package:fast_food_app/widgets/gradient_text.dart';
import 'package:fast_food_app/menu_customization_provider.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

class MenuCustomizationPage extends StatefulWidget {
  final MenuItem menuItem;
  final CartItem? cartItem;
  final String? cartItemKey;

  const MenuCustomizationPage({
    super.key,
    required this.menuItem,
    this.cartItem,
    this.cartItemKey,
  });

  @override
  State<MenuCustomizationPage> createState() => _MenuCustomizationPageState();
}

class _MenuCustomizationPageState extends State<MenuCustomizationPage> {
  String _proxiedImageUrl(String url) {
    return '${AppConfig.baseUrl}/api/image-proxy?url=${Uri.encodeComponent(url)}';
  }

  final MongoService _mongoService = MongoService();
  late int _quantity;
  late Map<String, List<Option>> _selectedOptions;
  late Set<String> _ingredientsToRemove;
  late bool _isEditing;
  late double _singleItemPrice;
  late double _totalPrice;
  final Map<String, bool> _expansionState = {};
  late final Map<String, Future<List<Option>>> _optionFutures;
  late ScrollController _scrollController;
  bool _isAppBarColored = false;
  final Color _accentColor = const Color(0xFF53c6fd);
  final List<String> _requiredOptionTypes = ['sauceOptions', 'drinkOptions'];

  @override
  void initState() {
    super.initState();

    _isEditing = widget.cartItem != null;
    _quantity = widget.cartItem?.quantity ?? 1;
    _ingredientsToRemove = Set<String>.from(widget.cartItem?.ingredientsToRemove ?? {});
    _selectedOptions = Map<String, List<Option>>.from(
      widget.cartItem?.selectedOptions.map(
        (key, value) => MapEntry(key, List<Option>.from(value))
      ) ?? {}
    );

    _optionFutures = {
      for (var type in widget.menuItem.optionTypes)
        type: _mongoService.getOptions(type)
    };

    _updatePrices();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.offset > 150 && !_isAppBarColored) {
      setState(() => _isAppBarColored = true);
    } else if (_scrollController.offset <= 150 && _isAppBarColored) {
      setState(() => _isAppBarColored = false);
    }
  }

  void _updatePrices() {
    double optionsPrice = 0.0;
    _selectedOptions.forEach((category, options) {
      optionsPrice += options.fold(0.0, (sum, option) => sum + (option.price > 0 ? option.price : 0.0));
    });

    _singleItemPrice = widget.menuItem.price + optionsPrice;
    setState(() {
      _totalPrice = _singleItemPrice * _quantity;
    });
  }
  
  void _setQuantity(int newQuantity) {
    if (newQuantity >= 1) {
      setState(() {
        _quantity = newQuantity;
        _updatePrices();
      });
    }
  }

  bool _isMultiChoice(String optionType) {
    return ['garnishOptions', 'sauceOptions'].contains(optionType);
  }

  void _saveChanges() {
    final List<String> missingSelections = [];
    for (String optionType in _requiredOptionTypes) {
      if (widget.menuItem.optionTypes.contains(optionType)) {
        if (_selectedOptions[optionType] == null || _selectedOptions[optionType]!.isEmpty) {
          missingSelections.add(_getOptionDisplayTitle(optionType).replaceAll('Avec ', '').toLowerCase());
        }
      }
    }

    if (missingSelections.isNotEmpty) {
      _showMissingSelectionDialog('Veuillez sélectionner: ${missingSelections.join(', ')}');
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    if (_isEditing && widget.cartItemKey != null) cart.removeItem(widget.cartItemKey!);

    Option? selectedSize;
    if (_selectedOptions.containsKey('sizeOptions') && _selectedOptions['sizeOptions']!.isNotEmpty) {
      selectedSize = _selectedOptions['sizeOptions']!.first;
    }
    
    cart.addItem(
      widget.menuItem,
      selectedOptions: _selectedOptions,
      ingredientsToRemove: _ingredientsToRemove,
      selectedSize: selectedSize,
      quantity: _quantity,
    );

    Navigator.pop(context);
  }

  String _getOptionDisplayTitle(String optionType) {
    if (widget.menuItem.optionDisplayTitles?.containsKey(optionType) ?? false) {
      return widget.menuItem.optionDisplayTitles![optionType]!;
    }
    switch (optionType) {
      case 'sizeOptions': return 'Taille';
      case 'garnishOptions': return 'Garniture';
      case 'sauceOptions': return 'Sauce';
      case 'drinkOptions': return 'Boisson';
      default: return optionType.replaceAll('Options', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(isDark),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? size.width * 0.2 : 16,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(isDark),
                    const SizedBox(height: 24),
                    ...widget.menuItem.optionTypes.map((type) => _buildDynamicOptionSection(type)),
                    if (widget.menuItem.removableIngredients.isNotEmpty)
                      _buildIngredientsToRemoveSection(),
                    _buildQuantitySelector(),
                    const SizedBox(height: 100), // Space for bottom button
                  ]),
                ),
              ),
            ],
          ),
          _buildBottomAction(isDark, isLargeScreen, size),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: widget.menuItem.imageUrl != null
            ? Hero(
                tag: 'item_${widget.menuItem.id}',
                child: Image.network(
                  _proxiedImageUrl(widget.menuItem.imageUrl!),
                  fit: BoxFit.cover,
                ),
              )
            : Container(color: _accentColor.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.menuItem.name,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_singleItemPrice.toStringAsFixed(2)} €',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _accentColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.menuItem.description ?? '',
          style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
        ),
      ],
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildBottomAction(bool isDark, bool isLargeScreen, Size size) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? size.width * 0.2 : 24,
          vertical: 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          top: false,
          child: GradientButton(
            onPressed: _saveChanges,
            text: _isEditing ? 'Mettre à jour (${_totalPrice.toStringAsFixed(2)} €)' : 'Ajouter au panier (${_totalPrice.toStringAsFixed(2)} €)',
            icon: Icons.shopping_basket_outlined,
            gradient: const LinearGradient(colors: [Color(0xFF53c6fd), Color(0xFF9c4dea)]),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicOptionSection(String optionType) {
    return FutureBuilder<List<Option>>(
      future: _optionFutures[optionType],
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final options = snapshot.data!;
        final title = _getOptionDisplayTitle(optionType);
        final isMulti = _isMultiChoice(optionType);
        final currentSelections = _selectedOptions[optionType] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_requiredOptionTypes.contains(optionType))
                    const Text(' *', style: TextStyle(color: Colors.red)),
                  const Spacer(),
                  if (currentSelections.isNotEmpty)
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: options.map((opt) {
                final isSelected = currentSelections.any((s) => s.id == opt.id);
                return _buildModernChip(
                  label: opt.name,
                  price: opt.price,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (!isMulti) {
                        _selectedOptions[optionType] = [opt];
                      } else {
                        if (isSelected) {
                          _selectedOptions[optionType]!.removeWhere((s) => s.id == opt.id);
                        } else {
                          _selectedOptions[optionType] = [...currentSelections, opt];
                        }
                      }
                      _updatePrices();
                    });
                  },
                );
              }).toList(),
            ),
            const Divider(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildModernChip({
    required String label,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? _accentColor : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: 2,
          ),
          boxShadow: isSelected ? [BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (price > 0)
              Text(
                ' (+${price.toStringAsFixed(2)}€)',
                style: TextStyle(
                  color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsToRemoveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text('Retirer des ingrédients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.menuItem.removableIngredients.map((ing) {
            final isRemoved = _ingredientsToRemove.contains(ing);
            return _buildModernChip(
              label: 'Sans $ing',
              price: 0,
              isSelected: isRemoved,
              onTap: () {
                setState(() {
                  if (isRemoved) _ingredientsToRemove.remove(ing);
                  else _ingredientsToRemove.add(ing);
                });
              },
            );
          }).toList(),
        ),
        const Divider(height: 40),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Quantité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildQtyBtn(Icons.remove, () => _setQuantity(_quantity - 1), _quantity > 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              _buildQtyBtn(Icons.add, () => _setQuantity(_quantity + 1), true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, bool enabled) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: enabled ? _accentColor : Colors.grey,
      iconSize: 28,
    );
  }

  void _showMissingSelectionDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text('Sélection requise'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
