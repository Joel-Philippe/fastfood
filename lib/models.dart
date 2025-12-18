import 'package:flutter/material.dart';

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String category;
  final List<String> optionTypes;
  final List<String> removableIngredients;
  final Map<String, String>? optionDisplayTitles; // NEW FIELD

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.optionTypes = const [],
    this.removableIngredients = const [],
    this.optionDisplayTitles, // NEW PARAMETER
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    List<String>? optionTypes,
    List<String>? removableIngredients,
    Map<String, String>? optionDisplayTitles, // NEW PARAMETER
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      optionTypes: optionTypes ?? this.optionTypes,
      removableIngredients: removableIngredients ?? this.removableIngredients,
      optionDisplayTitles: optionDisplayTitles ?? this.optionDisplayTitles, // NEW ASSIGNMENT
    );
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String?,
      category: map['category'] as String,
      optionTypes: List<String>.from(map['optionTypes'] ?? []),
      removableIngredients: List<String>.from(map['removableIngredients'] ?? []),
      optionDisplayTitles: (map['optionDisplayTitles'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value.toString()),
      ), // NEW PARSING
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'optionTypes': optionTypes,
      'removableIngredients': removableIngredients,
      'optionDisplayTitles': optionDisplayTitles, // NEW ADDITION
    };
  }
}

class Option {
  final String id;
  final String name;
  final String type;
  final double price; // Changed from priceModifier to price
  final String? imageUrl; // New field for imageUrl

  Option({
    required this.id,
    required this.name,
    required this.type,
    this.price = 0.0, // Changed from priceModifier to price
    this.imageUrl, // Initialize imageUrl
  });

  factory Option.fromMap(Map<String, dynamic> map) {
    return Option(
      id: map['_id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0, // Parse price
      imageUrl: map['imageUrl'], // Parse imageUrl
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'type': type,
      'price': price, // Use price
      'imageUrl': imageUrl, // Use imageUrl
    };
  }
}

class MenuCategory {
  final String id;
  final String name;
  final String type; // Changed from CategoryType to String
  final String? fontColor;
  final String? backgroundColor;
  final String? backgroundImageUrl;

  MenuCategory({
    required this.id,
    required this.name,
    required this.type, // Changed from CategoryType to String
    this.fontColor,
    this.backgroundColor,
    this.backgroundImageUrl,
  });

  Color get backgroundColorAsColor {
    if (backgroundColor != null && backgroundColor!.isNotEmpty) {
      final buffer = StringBuffer();
      if (backgroundColor!.length == 6 || backgroundColor!.length == 7) buffer.write('ff');
      buffer.write(backgroundColor!.replaceFirst('#', ''));
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (e) {
        // Return a default color if parsing fails
        return Colors.grey[200]!;
      }
    }
    return Colors.grey[200]!; // Default color
  }

  Color get fontColorAsColor {
    if (fontColor != null && fontColor!.isNotEmpty) {
      final buffer = StringBuffer();
      if (fontColor!.length == 6 || fontColor!.length == 7) buffer.write('ff');
      buffer.write(fontColor!.replaceFirst('#', ''));
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (e) {
        // Return a default color if parsing fails
        return Colors.black; // Default to black
      }
    }
    return Colors.black; // Default to black
  }

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['_id'] as String,
      name: map['name'] as String,
      type: map['type'] as String, // Changed to read String directly
      fontColor: map['fontColor'] as String?,
      backgroundColor: map['backgroundColor'] as String?,
      backgroundImageUrl: map['backgroundImageUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class DailyHours {
  bool isOpen;
  String openTime;
  String closeTime;

  DailyHours({
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory DailyHours.fromMap(Map<String, dynamic> map) {
    return DailyHours(
      isOpen: map['isOpen'] ?? true,
      openTime: map['openTime'] ?? '11:00',
      closeTime: map['closeTime'] ?? '22:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOpen': isOpen,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }
}

class RestaurantSettings {
  final Map<String, DailyHours> hours;

  RestaurantSettings({required this.hours});

  factory RestaurantSettings.fromMap(Map<String, dynamic> map) {
    final hoursData = map['hours'] as Map<String, dynamic>? ?? {};
    final hours = hoursData.map(
      (key, value) => MapEntry(key, DailyHours.fromMap(value as Map<String, dynamic>)),
    );
    return RestaurantSettings(hours: hours);
  }

  Map<String, dynamic> toMap() {
    return {
      'hours': hours.map((key, value) => MapEntry(key, value.toMap())),
    };
  }
}
