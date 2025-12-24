import 'dart:convert';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/models.dart';

class Address {
  final String street;
  final String city;
  final String postalCode;
  final String phone;

  Address({
    required this.street,
    required this.city,
    required this.postalCode,
    required this.phone,
  });

  factory Address.fromMap(Map<String, dynamic> data) {
    return Address(
      street: data['street'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}

class Order {
  final String id;
  final String customerName;
  final String orderType; // 'takeaway', 'eat_in', or 'delivery'
  final String? arrivalTime; // Only if orderType is 'eat_in'
  final Map<String, CartItem> items;
  final double totalAmount;
  final DateTime orderDate;
  String status; // e.g., 'pending', 'preparing', 'ready', 'out_for_delivery', 'completed'

  // Delivery details are now in a dedicated Address object
  final Address? address;

  Order({
    required this.id,
    required this.customerName,
    required this.orderType,
    this.arrivalTime,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    this.status = 'pending',
    this.address,
  });

  // Method to convert an Order object to a map (e.g., for MongoDB backend)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'customerName': customerName,
      'orderType': orderType,
      // 'arrivalTime' is handled conditionally below
      'items': items.values.map((cartItem) => {
        'itemId': cartItem.item.id,
        'itemName': cartItem.item.name,
        'itemDescription': cartItem.item.description,
        'itemPrice': cartItem.item.price,
        'itemImageUrl': cartItem.item.imageUrl,
        'itemCategory': cartItem.item.category.toString().split('.').last,
        'quantity': cartItem.quantity,
        'itemOptions': cartItem.selectedOptions.map(
          (key, value) => MapEntry(key, value.map((option) => option.toMap()).toList())
        ),
        'excludedIngredients': cartItem.ingredientsToRemove.toList(), // Convert Set to List for JSON
      }).toList(),
      'totalAmount': totalAmount,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
    };

    if (arrivalTime != null) {
      map['arrivalTime'] = arrivalTime;
    }

    if (orderType == 'delivery' && address != null) {
      map['address'] = {
        'street': address!.street,
        'city': address!.city,
        'postalCode': address!.postalCode,
        'phone': address!.phone,
      };
    }
    
    return map;
  }

  // Factory constructor for creating an Order from a map (e.g., from MongoDB backend)
  factory Order.fromMap(Map<String, dynamic> data, String id) {
    final List<dynamic> itemsData = data['items'] ?? [];
    final Map<String, CartItem> items = {};
    for (var itemMap in itemsData) {
      final menuItem = MenuItem(
        id: itemMap['itemId'] ?? '',
        name: itemMap['itemName'] ?? '',
        description: itemMap['itemDescription'] ?? '',
        price: (itemMap['itemPrice'] as num?)?.toDouble() ?? 0.0,
        imageUrl: itemMap['itemImageUrl'] ?? '',
        category: itemMap['itemCategory'] ?? 'uncategorized', // Now a String
        // Note: The detailed options of the base MenuItem are not needed here
        // as we are reconstructing a specific cart item instance.
      );

      final optionsData = itemMap['itemOptions'];
      final Map<String, List<Option>> selectedOptions;

      if (optionsData is Map<String, dynamic>) {
        selectedOptions = optionsData.map(
          (key, value) => MapEntry(
            key,
            List<Option>.from((value as List).map((o) => Option.fromMap(o as Map<String, dynamic>))),
          ),
        );
      } else {
        // Handle corrupted data (e.g., it's a List or null) by treating it as empty.
        selectedOptions = {};
      }

      final ingredientsToRemove = Set<String>.from(itemMap['excludedIngredients'] ?? []);

      final cartItem = CartItem(
        item: menuItem,
        quantity: itemMap['quantity'] ?? 1,
        selectedOptions: selectedOptions,
        ingredientsToRemove: ingredientsToRemove,
      );

      // Recreate the unique key to store it in the map
      final sortedOptions = Map.fromEntries(
        selectedOptions.entries.map((e) => MapEntry(e.key, List.from(e.value)..sort()))
          .toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      final sortedIngredients = List.from(ingredientsToRemove)..sort();
      final customizationString = json.encode({'options': sortedOptions, 'removed': sortedIngredients});
      final key = '${menuItem.id}-$customizationString';

      items[key] = cartItem;
    }

    final addressData = data['address'] as Map<String, dynamic>?;

    return Order(
      id: data['_id'] ?? id,
      customerName: data['customerName'] ?? '',
      orderType: data['orderType'] ?? 'takeaway',
      arrivalTime: data['arrivalTime'],
      items: items,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderDate: DateTime.parse(data['orderDate'] ?? DateTime.now().toIso8601String()),
      status: data['status'] ?? 'pending',
      address: addressData != null ? Address.fromMap(addressData) : null,
    );
  }
}