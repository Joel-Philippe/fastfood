import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/order_model.dart';
import 'package:fast_food_app/services/auth_service.dart'; // Import AuthService
import 'package:fast_food_app/app_config.dart';
import 'package:image_picker/image_picker.dart';

class MongoService {
  final String _baseUrl = '${AppConfig.baseUrl}/api'; // Replace with your backend API URL
  final AuthService _authService = AuthService(); // Instantiate AuthService

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('No authentication token found. Please log in.');
    }

    if (await _authService.isTokenExpired(token)) {
      throw Exception('Your session has expired. Please log out and log in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Image Upload ---
  Future<String> uploadImage(File? imageFile, {Uint8List? imageBytes, String? fileName}) async {
    final headers = await _getAuthHeaders();
    headers.remove('Content-Type'); // Remove Content-Type for MultipartRequest, it will be set automatically

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload/image'),
    );
    request.headers.addAll(headers);

    if (kIsWeb && imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: fileName));
    } else if (!kIsWeb && imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    } else {
      throw Exception('No image data provided.');
    }

    var response = await request.send();

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(responseBody);
      return decodedResponse['imageUrl'];
    } else {
      throw Exception('Failed to upload image: ${response.statusCode} - $responseBody');
    }
  }

  // --- Category Management ---

  Future<List<MenuCategory>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/menu/categories'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<MenuCategory>.from(l.map((model) => MenuCategory.fromMap(model)));
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<void> addCategory({
    required String name,
    required String type,
    String? fontColor,
    String? backgroundColor,
    XFile? imageFile,
  }) async {
    final headers = await _getAuthHeaders();
    // Multipart request needs a different content-type, which http.MultipartRequest handles.
    headers.remove('Content-Type');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/menu/categories'),
    );
    request.headers.addAll(headers);

    // Add text fields
    request.fields['name'] = name;
    request.fields['type'] = type;
    if (fontColor != null) {
      request.fields['fontColor'] = fontColor;
    }
    if (backgroundColor != null) {
      request.fields['backgroundColor'] = backgroundColor;
    }

    // Add image file if provided
    if (imageFile != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('image', await imageFile.readAsBytes(), filename: imageFile.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }
    }

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      try {
        final error = json.decode(responseBody);
        throw Exception(error['message'] ?? 'Failed to add category');
      } catch (e) {
        throw Exception('Failed to add category: ${response.statusCode} - $responseBody');
      }
    }
  }

  Future<void> updateCategory(String id, String name, String type, {String? fontColor, String? backgroundColor}) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/menu/categories/$id'),
      headers: headers,
      body: json.encode({
        'name': name,
        'type': type,
        'fontColor': fontColor,
        'backgroundColor': backgroundColor,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update category details');
    }
  }

  Future<void> updateCategoryImage({required String categoryId, required XFile imageFile}) async {
    final headers = await _getAuthHeaders();
    headers.remove('Content-Type'); // Let the multipart request set its own content type

    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/menu/categories/$categoryId/background-image'),
    );
    request.headers.addAll(headers);

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes('image', await imageFile.readAsBytes(), filename: imageFile.name));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      try {
        final error = json.decode(responseBody);
        throw Exception(error['message'] ?? 'Failed to update category image');
      } catch (e) {
        throw Exception('Failed to update category image: ${response.statusCode} - $responseBody');
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/menu/categories/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete category');
    }
  }

  // --- Menu Item Management ---

  Future<List<MenuItem>> getMenuItems(String categoryTypeString) async {
    final response = await http.get(Uri.parse('$_baseUrl/menu?category=${categoryTypeString}'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<MenuItem>.from(l.map((model) => MenuItem.fromMap(model)));
    } else {
      throw Exception('Failed to load menu items');
    }
  }

    Future<List<MenuItem>> getMenuItemsForAdmin() async {
      final headers = await _getAuthHeaders();
      final response = await http.get(Uri.parse('$_baseUrl/menu'), headers: headers);

      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<MenuItem>.from(l.map((model) => MenuItem.fromMap(model)));
    } else {
      throw Exception('Failed to load menu items');
    }
  }

  Future<void> addMenuItem(MenuItem item, {File? imageFile, Uint8List? imageBytes, String? fileName}) async {
    String? imageUrl = item.imageUrl;
    if (kIsWeb && imageBytes != null) {
      imageUrl = await uploadImage(null, imageBytes: imageBytes, fileName: fileName);
    } else if (!kIsWeb && imageFile != null) {
      imageUrl = await uploadImage(imageFile);
    }

    final headers = await _getAuthHeaders();
    final Map<String, dynamic> body = item.toMap();
    if (imageUrl != null) {
      body['imageUrl'] = imageUrl;
    }


    final response = await http.post(
      Uri.parse('$_baseUrl/menu'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode != 201) {
      try {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to add menu item');
      } catch (e) {
        throw Exception('Failed to add menu item');
      }
    }
  }

  Future<void> updateMenuItem(MenuItem item, {File? imageFile, Uint8List? imageBytes, String? fileName}) async {
    String? imageUrl = item.imageUrl;
    if (kIsWeb && imageBytes != null) {
      imageUrl = await uploadImage(null, imageBytes: imageBytes, fileName: fileName);
    } else if (!kIsWeb && imageFile != null) {
      imageUrl = await uploadImage(imageFile);
    }

    final headers = await _getAuthHeaders();
    final Map<String, dynamic> body = item.toMap();
    if (imageUrl != null) {
      body['imageUrl'] = imageUrl;
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/menu/${item.id}'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      try {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update menu item');
      } catch (e) {
        throw Exception('Failed to update menu item');
      }
    }
  }

  Future<void> deleteMenuItem(String itemId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/menu/$itemId'), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete menu item');
    }
  }

  // --- Option Management ---

  Future<List<String>> getOptionTypes() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/menu/options/types'), headers: headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<String>.from(l.map((model) => model.toString()));
    } else {
      throw Exception('Failed to load option types');
    }
  }

  Future<List<Option>> getOptions(String collectionName) async {
    final response = await http.get(Uri.parse('$_baseUrl/menu/options/$collectionName'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Option>.from(l.map((model) => Option.fromMap(model)));
    } else {
      throw Exception('Failed to load options');
    }
  }

  Future<void> addOption(String collectionName, String optionName, double price) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/menu/options'),
      headers: headers,
      body: json.encode({
        'name': optionName,
        'type': collectionName,
        'price': price,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add option');
    }
  }

  Future<void> updateOption(String collectionName, String optionId, String newName, double price) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/menu/options/$optionId'),
      headers: headers,
      body: json.encode({'name': newName, 'price': price}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update option');
    }
  }

  Future<void> deleteOption(String collectionName, String optionId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/menu/options/$optionId'), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete option');
    }
  }

  // --- Order Management ---

  Future<void> placeOrder(Order order) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/orders'),
      headers: headers,
      body: json.encode(order.toMap()),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to place order');
    }
  }

  Future<List<Order>> getMyOrders() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/orders/my-orders'), headers: headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Order>.from(l.map((model) => Order.fromMap(model, model['_id'])));
    } else {
      throw Exception('Failed to load your orders');
    }
  }

  Future<List<Order>> getOrders() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/orders'), headers: headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Order>.from(l.map((model) => Order.fromMap(model, model['_id'])));
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final headers = await _getAuthHeaders();
    final response = await http.patch(
      Uri.parse('$_baseUrl/orders/$orderId/status'),
      headers: headers,
      body: json.encode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update order status');
    }
  }

  // --- Restaurant Settings ---

  Future<RestaurantSettings> getSettings() async {
    // This is a public endpoint, no auth needed
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await http.get(Uri.parse('$_baseUrl/settings?t=$timestamp'));
    if (response.statusCode == 200) {
      return RestaurantSettings.fromMap(json.decode(response.body));
    } else {
      throw Exception('Failed to load restaurant settings');
    }
  }

  Future<void> updateSettings(RestaurantSettings settings) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/settings'),
      headers: headers,
      body: json.encode(settings.toMap()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }
}