import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';
import 'dart:convert';

class CartItem {
  final MenuItem item;
  int quantity;
  final Map<String, List<Option>> selectedOptions;
  final Set<String> ingredientsToRemove;
  final Option? selectedSize; // New field for selected size

  CartItem({
    required this.item,
    this.quantity = 1,
    this.selectedOptions = const {},
    this.ingredientsToRemove = const {},
    this.selectedSize, // Initialize selectedSize
  });

  // Method to get total price for this cart item, accounting for size and options
  double get totalPrice {
    // Calculate the sum of prices for selected options with price > 0
    double optionsPrice = 0.0;
    selectedOptions.forEach((category, options) {
      optionsPrice += options.fold(0.0, (sum, option) =>
          sum + (option.price > 0 ? option.price : 0.0)
      );
    });

    // If the calculated options price is 0 (meaning either no options are selected,
    // or all selected options have a price of 0), use the item's base price.
    // Otherwise, use the calculated options price.
    if (optionsPrice == 0.0) {
      return item.price * quantity;
    } else {
      return optionsPrice * quantity;
    }
  }
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  void addItem(MenuItem item, {Map<String, List<Option>> selectedOptions = const {}, Set<String> ingredientsToRemove = const {}, Option? selectedSize}) {
    // Create a canonical representation of the options and ingredients to remove
    final sortedIdOptions = selectedOptions.map((key, value) {
      final ids = value.map((opt) => opt.id).toList()..sort();
      return MapEntry(key, ids);
    });

    final sortedEntries = sortedIdOptions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final sortedOptionsForKeey = Map.fromEntries(sortedEntries);

    final sortedIngredients = List.from(ingredientsToRemove)..sort();
    
    final customizationMap = {
      'options': sortedOptionsForKeey,
      'removed': sortedIngredients,
      'sizeId': selectedSize?.id, // Include size ID in customization for key
    };
    final customizationString = json.encode(customizationMap);
    final key = '${item.id}-$customizationString';

    if (_items.containsKey(key)) {
      _items.update(
        key,
        (existingItem) => CartItem(
          item: existingItem.item,
          quantity: existingItem.quantity + 1,
          selectedOptions: existingItem.selectedOptions,
          ingredientsToRemove: existingItem.ingredientsToRemove,
          selectedSize: existingItem.selectedSize, // Ensure selectedSize is passed back
        ),
      );
    } else {
      _items.putIfAbsent(
        key,
        () => CartItem(
          item: item,
          selectedOptions: selectedOptions,
          ingredientsToRemove: ingredientsToRemove,
          selectedSize: selectedSize, // Pass selectedSize to new CartItem
        ),
      );
    }
    notifyListeners();
  }

  void removeItem(String cartItemKey) {
    _items.remove(cartItemKey);
    notifyListeners();
  }

  void updateItemQuantity(String cartItemKey, int newQuantity) {
    if (_items.containsKey(cartItemKey)) {
      if (newQuantity <= 0) {
        _items.remove(cartItemKey);
      } else {
        _items.update(
          cartItemKey,
          (existingItem) => CartItem(
            item: existingItem.item,
            quantity: newQuantity,
            selectedOptions: existingItem.selectedOptions,
            ingredientsToRemove: existingItem.ingredientsToRemove,
            selectedSize: existingItem.selectedSize,
          ),
        );
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  bool isItemInCart(String menuItemId) {
    return _items.values.any((cartItem) => cartItem.item.id == menuItemId);
  }
}
