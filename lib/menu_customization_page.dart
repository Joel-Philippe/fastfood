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
  final Color _appBarScrollColor = const Color(0xFF53c6fd);
  final List<String> _requiredOptionTypes = ['sauceOptions', 'drinkOptions'];

  @override
  void initState() {
    super.initState();

    final customizationProvider = Provider.of<MenuCustomizationProvider>(context, listen: false);
    final savedState = customizationProvider.getCustomization(widget.menuItem.id);

    _isEditing = widget.cartItem != null;

    if (savedState != null) {
      _selectedOptions = savedState.selectedOptions;
      _ingredientsToRemove = savedState.ingredientsToRemove;
      _quantity = savedState.quantity;
    } else {
      _selectedOptions = Map<String, List<Option>>.from(
        widget.cartItem?.selectedOptions.map(
          (key, value) => MapEntry(key, List<Option>.from(value))
        ) ?? {}
      );
      _ingredientsToRemove = Set<String>.from(widget.cartItem?.ingredientsToRemove ?? {});
      _quantity = widget.cartItem?.quantity ?? 1;
    }

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
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.offset > 50 && !_isAppBarColored) {
      setState(() {
        _isAppBarColored = true;
      });
    } else if (_scrollController.offset <= 50 && _isAppBarColored) {
      setState(() {
        _isAppBarColored = false;
      });
    }
  }

  void _saveStateToProvider() {
    final customizationProvider = Provider.of<MenuCustomizationProvider>(context, listen: false);
    final currentState = CustomizationState(
      selectedOptions: _selectedOptions,
      ingredientsToRemove: _ingredientsToRemove,
      quantity: _quantity,
    );
    customizationProvider.updateCustomization(widget.menuItem.id, currentState);
  }

  void _updatePrices() {
    double optionsPrice = 0.0;
    _selectedOptions.forEach((category, options) {
      optionsPrice += options.fold(0.0, (sum, option) =>
          sum + (option.price > 0 ? option.price : 0.0)
      );
    });

    double currentPrice;
    if (optionsPrice == 0.0) {
      currentPrice = widget.menuItem.price;
    } else {
      currentPrice = optionsPrice;
    }

    setState(() {
      _singleItemPrice = currentPrice;
      _totalPrice = _singleItemPrice * _quantity;
      _saveStateToProvider();
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
    const multiChoiceTypes = ['garnishOptions', 'sauceOptions'];
    return multiChoiceTypes.contains(optionType);
  }

  void _showMissingSelectionDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFc4f8ea), Color(0xFFfef1e0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.info_outline, color: Colors.black54, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Sélection requise',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Compris',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut);
      },
    );
  }

  void _saveChanges() {
    final List<String> requiredOptionTypes = _requiredOptionTypes;
    final List<String> missingSelections = [];
    for (String optionType in requiredOptionTypes) {
      if (widget.menuItem.optionTypes.contains(optionType)) {
        if (_selectedOptions[optionType] == null || _selectedOptions[optionType]!.isEmpty) {
          missingSelections.add(_getOptionDisplayTitle(optionType).replaceAll('Avec ', '').toLowerCase());
        }
      }
    }

    if (missingSelections.isNotEmpty) {
      final message = 'Veuillez sélectionner: ${missingSelections.join(', ')}';
      _showMissingSelectionDialog(message);
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    final customizationProvider = Provider.of<MenuCustomizationProvider>(context, listen: false);

    if (_isEditing && widget.cartItemKey != null) {
      cart.removeItem(widget.cartItemKey!);
    }

    const sizeOptionKey = 'sizeOptions';
    Option? selectedSize;
    if (_selectedOptions.containsKey(sizeOptionKey) && _selectedOptions[sizeOptionKey]!.isNotEmpty) {
      selectedSize = _selectedOptions[sizeOptionKey]!.first;
    }
    
    for (int i = 0; i < _quantity; i++) {
      cart.addItem(
        widget.menuItem,
        selectedOptions: _selectedOptions,
        ingredientsToRemove: _ingredientsToRemove,
        selectedSize: selectedSize,
      );
    }

    customizationProvider.clearCustomization(widget.menuItem.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
        content: Text(
          '${widget.menuItem.name} ${_isEditing ? 'modifié' : 'ajouté au panier !'}',
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        ),
      ),
    );
    Navigator.pop(context);
  }

  String _getOptionDisplayTitle(String optionType) {
    if (widget.menuItem.optionDisplayTitles != null &&
        widget.menuItem.optionDisplayTitles!.containsKey(optionType)) {
      return widget.menuItem.optionDisplayTitles![optionType]!;
    }

    switch (optionType) {
      case 'sizeOptions':
        return 'Taille';
      case 'garnishOptions':
        return 'Garniture';
      case 'sauceOptions':
        return 'Sauce';
      case 'drinkOptions':
        return 'Boisson';
      default:
        return optionType.replaceAll('Options', '').replaceFirst(optionType[0], optionType[0].toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFfdf9e0),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 250.0,
              pinned: true,
              backgroundColor: _isAppBarColored ? _appBarScrollColor : Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '${widget.menuItem.name} (${_singleItemPrice.toStringAsFixed(2)} €)',
                  style: const TextStyle(
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: widget.menuItem.imageUrl != null && widget.menuItem.imageUrl!.isNotEmpty
                    ? Image.network(
                        _proxiedImageUrl(widget.menuItem.imageUrl!),
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.1),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.black.withOpacity(0.1),
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(color: const Color(0xFFcdc4bf).withOpacity(0.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.menuItem.description ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 16,
                        height: 1.5,
                      ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final optionType = widget.menuItem.optionTypes[index];
                  return _buildDynamicOptionSection(optionType);
                },
                childCount: widget.menuItem.optionTypes.length,
              ),
            ),
            if (widget.menuItem.removableIngredients.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildIngredientsToRemoveSection(),
              ),
            SliverToBoxAdapter(child: _buildQuantitySelector()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GradientButton(
                  onPressed: _saveChanges,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF53c6fd), Color(0xFF53c6fd)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  text: _isEditing ? 'Modifier l\'article (${_totalPrice.toStringAsFixed(2)} €)' : 'Ajouter au panier (${_totalPrice.toStringAsFixed(2)} €)',
                  icon: _isEditing ? Icons.edit : Icons.add_shopping_cart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicOptionSection(String optionType) {
    return FutureBuilder<List<Option>>(
      future: _optionFutures[optionType],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final options = snapshot.data!;
        final title = _getOptionDisplayTitle(optionType);
        final isMulti = _isMultiChoice(optionType);
        
        List<Option> currentSelections = _selectedOptions[optionType] ?? [];

        final gradientTitle = GradientWidget(
          gradient: const LinearGradient(
            colors: [Color(0xFF8ec44d), Color(0xFFb1b77b)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (_requiredOptionTypes.contains(optionType) && currentSelections.isEmpty)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                  ),
              ],
            ),
          ),
        );

        final checkmarkGradient = const LinearGradient(
          colors: [Color(0xFF3a5d2a), Color(0xFF07f916)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );

        final trailingIcon = currentSelections.isNotEmpty
            ? GradientWidget(
                gradient: checkmarkGradient,
                child: const Icon(Icons.check_circle, color: Colors.white),
              )
            : const GradientWidget(
                gradient: LinearGradient(
                  colors: [Color(0xFF06a9f6), Color(0xFFffacac)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                child: Icon(Icons.add_circle_outline, color: Colors.white),
              );

        return _buildExpansionTileBase(
          tileKey: optionType,
          title: gradientTitle,
          subtitle: currentSelections.isNotEmpty
              ? GradientWidget(
                  gradient: checkmarkGradient,
                  child: Text(
                    'Avec: ${currentSelections.map((opt) => opt.name).join(', ')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : const Text(
                  'Faites votre choix',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
          hasSelection: currentSelections.isNotEmpty,
          trailing: trailingIcon,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: options.map((option) {
                final isSelected = currentSelections.any((opt) => opt.id == option.id);
                return _buildOptionChip(
                  option: option,
                  isSelected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (isMulti) {
                        final newSelections = List<Option>.from(currentSelections);
                        if (selected) {
                          newSelections.add(option);
                        } else {
                          newSelections.removeWhere((opt) => opt.id == option.id);
                        }
                        _selectedOptions[optionType] = newSelections;
                      } else {
                         _selectedOptions[optionType] = selected ? [option] : [];
                      }
                      _updatePrices();
                    });
                  },
                );
              }).toList(),
            )
          ],
        );
      },
    );
  }
  
  Widget _buildIngredientsToRemoveSection() {
    const key = 'removableIngredients';

    final gradientTitle = GradientWidget(
      gradient: const LinearGradient(
        colors: [Color(0xFFe05601), Color(0xFFff7a7b)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      child: const Text('Retirer des ingrédients?', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
    );

    final trailingIcon = _ingredientsToRemove.isNotEmpty
        ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
        : const GradientWidget(
            gradient: LinearGradient(
              colors: [Color(0xFF7a4924), Color(0xFFffacac)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            child: Icon(Icons.remove_circle_outline, color: Colors.white),
          );

    return _buildExpansionTileBase(
      tileKey: key,
      title: gradientTitle,
      subtitle: Text(
        _ingredientsToRemove.isNotEmpty ? 'J\'enlève: ${_ingredientsToRemove.join(', ')}' : 'Aucun ingrédient à retirer',
        style: TextStyle(color: _ingredientsToRemove.isNotEmpty ? Colors.deepOrange : Colors.grey, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      hasSelection: _ingredientsToRemove.isNotEmpty,
      trailing: trailingIcon,
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: widget.menuItem.removableIngredients.map((ingredient) {
            final isSelected = _ingredientsToRemove.contains(ingredient);
            return _buildOptionChip(
              option: Option(id: ingredient, name: ingredient, price: 0.0, type: 'removable_ingredient_type'),
              isSelected: isSelected,
              isRemovable: true,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _ingredientsToRemove.add(ingredient);
                  } else {
                    _ingredientsToRemove.remove(ingredient);
                  }
                  _saveStateToProvider();
                });
              },
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildExpansionTileBase({
    required String tileKey, 
    required Widget title, 
    required List<Widget> children,
    Widget? subtitle,
    bool hasSelection = false,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>(tileKey),
        initiallyExpanded: _expansionState[tileKey] ?? false,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _expansionState[tileKey] = expanded;
          });
        },
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: children,
      ),
    );
  }
  
  Widget _buildOptionChip({
    required Option option,
    required bool isSelected,
    required Function(bool) onSelected,
    bool isRemovable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color selectedBgColor = isRemovable ? const Color(0xFFFF7A7B) : const Color(0xFF53C6FD);
    final Color selectedBorderColor = isRemovable ? const Color(0xFFFF7A7B) : const Color(0xFF53C6FD);
    final Color unselectedBgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final Color selectedTextColor = Colors.white;
    
    final priceText = !isRemovable && option.price > 0 ? ' (${option.price.toStringAsFixed(2)} €)' : '';

    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? selectedBorderColor : (isDark ? Colors.white10 : Colors.grey[300]!),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: selectedBgColor.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3)
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(isRemovable ? Icons.remove_circle_outline : Icons.check_circle, color: Colors.white, size: 18),
              ),
            Flexible(
              child: Text(
                '${option.name}$priceText',
                style: TextStyle(
                  color: isSelected ? selectedTextColor : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuantitySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Text('Quantité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 30),
                onPressed: () => _setQuantity(_quantity - 1),
                color: _quantity > 1 ? (isDark ? Colors.white70 : Colors.black54) : Colors.grey[400],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  '$_quantity',
                  key: ValueKey<int>(_quantity),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 30),
                onPressed: () => _setQuantity(_quantity + 1),
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
