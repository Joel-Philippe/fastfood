import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:fast_food_app/app_config.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final String _baseUrl = '${AppConfig.baseUrl}/api/auth';
  final _storage = const FlutterSecureStorage();
  final String _tokenKey = 'auth_token';

  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody.containsKey('token')) {
          await _storage.write(key: _tokenKey, value: responseBody['token']);
        } else {
          throw Exception('Login successful, but no token received.');
        }
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Login failed with status code: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Login Error: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      if (response.statusCode != 201) {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Registration failed with status code: ${response.statusCode}';
        throw AuthException(errorMessage);
      }
    } catch (e) {
      throw AuthException('Failed to register. Please try again. Error: $e');
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<String?> getUserRole() async {
    final token = await getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['role'];
    }
    return null;
  }

  Future<String?> getUserName() async {
    final token = await getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['userName'];
    }
    return null;
  }

  Future<bool> isTokenExpired(String token) async {
    return JwtDecoder.isExpired(token);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && !await isTokenExpired(token);
  }

  Future<void> updateFCMToken(String fcmToken) async {
    final token = await getToken();
    if (token == null || await isTokenExpired(token)) {
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'fcmToken': fcmToken,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to update FCM token with status: ${response.statusCode}';
        throw AuthException(errorMessage);
      }
      debugPrint('FCM token successfully sent to backend.');
    } catch (e) {
      throw AuthException('Error updating FCM token: $e');
    }
  }
}
