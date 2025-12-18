import 'package:fast_food_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'dart:convert'; // Added for json.encode

void main() {
  // Helper function to generate the cart item key, mirroring CartProvider's logic
  String generateCartItemKey(MenuItem item, {Map<String, List<Option>> selectedOptions = const {}, Set<String> ingredientsToRemove = const {}, Option? selectedSize}) {
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
    return '${item.id}-$customizationString';
  }

  group('CartProvider', () {
    test('should add item to cart', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Item',
        description: 'Description',
        price: 10.0,
        imageUrl: 'url',
        category: 'assiettes',
      );

      final cartItemKey = generateCartItemKey(menuItem);
      cartProvider.addItem(menuItem);

      expect(cartProvider.itemCount, 1);
      expect(cartProvider.totalAmount, 10.0);
      expect(cartProvider.items[cartItemKey]!.quantity, 1);
    });

    test('should increase quantity if item already in cart', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Item',
        description: 'Description',
        price: 10.0,
        imageUrl: 'url',
        category: 'assiettes',
      );

      final cartItemKey = generateCartItemKey(menuItem);
      cartProvider.addItem(menuItem);
      cartProvider.addItem(menuItem);

      expect(cartProvider.itemCount, 2);
      expect(cartProvider.totalAmount, 20.0);
      expect(cartProvider.items[cartItemKey]!.quantity, 2);
    });

    test('should remove item from cart', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Item',
        description: 'Description',
        price: 10.0,
        imageUrl: 'url',
        category: 'assiettes',
      );

      final cartItemKey = generateCartItemKey(menuItem);
      cartProvider.addItem(menuItem);
      cartProvider.removeItem(cartItemKey);

      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
      expect(cartProvider.items.containsKey(cartItemKey), false);
    });

    test('should update item quantity', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Item',
        description: 'Description',
        price: 10.0,
        imageUrl: 'url',
        category: 'assiettes',
      );

      final cartItemKey = generateCartItemKey(menuItem);
      cartProvider.addItem(menuItem);
      cartProvider.updateItemQuantity(cartItemKey, 3);

      expect(cartProvider.itemCount, 3);
      expect(cartProvider.totalAmount, 30.0);
      expect(cartProvider.items[cartItemKey]!.quantity, 3);
    });

    test('should remove item if quantity updated to 0', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Item',
        description: 'Description',
        price: 10.0,
        imageUrl: 'url',
        category: 'assiettes',
      );

      final cartItemKey = generateCartItemKey(menuItem);
      cartProvider.addItem(menuItem);
      cartProvider.updateItemQuantity(cartItemKey, 0);

      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
      expect(cartProvider.items.containsKey(cartItemKey), false);
    });

    test('should clear cart', () {
      final cartProvider = CartProvider();
      final menuItem1 = MenuItem(
        id: '1',
        name: 'Test Item 1',
        description: 'Description 1',
        price: 10.0,
        imageUrl: 'url1',
        category: 'assiettes',
      );
      final menuItem2 = MenuItem(
        id: '2',
        name: 'Test Item 2',
        description: 'Description 2',
        price: 15.0,
        imageUrl: 'url2',
        category: 'sandwichs',
      );

      // We still generate keys to ensure consistency, even if clearCart doesn't directly use them
      // final cartItemKey1 = generateCartItemKey(menuItem1);
      // final cartItemKey2 = generateCartItemKey(menuItem2);

      cartProvider.addItem(menuItem1);
      cartProvider.addItem(menuItem2);
      cartProvider.clearCart();

      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
      expect(cartProvider.items.isEmpty, true);
    });

    test('should calculate total price correctly with size and options', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Burger',
        description: 'A test burger',
        price: 8.0, // Base price is ignored in the new logic
        imageUrl: 'url',
        category: 'sandwichs',
      );

      final sizeOption = Option(
        id: 'size_large',
        name: 'Large',
        price: 10.0, // Price of this option
        type: 'sizeOptions',
      );

      final toppingOption = Option(
        id: 'topping_cheese',
        name: 'Extra Cheese',
        price: 1.5, // Price of this option
        type: 'garnishOptions',
      );

      final zeroPriceOption = Option(
        id: 'zero_price_condiment',
        name: 'Ketchup',
        price: 0.0, // This price should be ignored
        type: 'condimentOptions',
      );

      // Add item with size, topping, and zero-price option
      cartProvider.addItem(
        menuItem,
        selectedOptions: {
          'sizeOptions': [sizeOption],
          'garnishOptions': [toppingOption],
          'condimentOptions': [zeroPriceOption], // Add zero-price option
        },
        selectedSize: sizeOption,
      );

      // Expected price is the sum of all option prices where price > 0: 10.0 + 1.5 = 11.5
      expect(cartProvider.totalAmount, 11.5);

      // Add the same item again to check quantity update
      cartProvider.addItem(
        menuItem,
        selectedOptions: {
          'sizeOptions': [sizeOption],
          'garnishOptions': [toppingOption],
          'condimentOptions': [zeroPriceOption], // Add zero-price option
        },
        selectedSize: sizeOption,
      );

      // Expected price = 11.5 * 2 = 23.0
      expect(cartProvider.itemCount, 2);
      expect(cartProvider.totalAmount, 23.0);
    });

    test('should use base price if only zero-priced options are selected', () {
      final cartProvider = CartProvider();
      final menuItem = MenuItem(
        id: '1',
        name: 'Test Burger',
        description: 'A test burger',
        price: 8.0, // Base price
        imageUrl: 'url',
        category: 'sandwichs',
      );

      final zeroPriceOption1 = Option(
        id: 'condiment_ketchup',
        name: 'Ketchup',
        price: 0.0,
        type: 'condimentOptions',
      );

      final zeroPriceOption2 = Option(
        id: 'condiment_mustard',
        name: 'Mustard',
        price: 0.0,
        type: 'condimentOptions',
      );

      // Add item with only zero-priced options
      cartProvider.addItem(
        menuItem,
        selectedOptions: {
          'condimentOptions': [zeroPriceOption1, zeroPriceOption2],
        },
      );

      // Expected price is the item's base price because all selected options have a price of 0
      expect(cartProvider.totalAmount, 8.0);
    });
  });
}
