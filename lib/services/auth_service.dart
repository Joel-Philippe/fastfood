import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:fast_food_app/main.dart'; // Import main.dart to access BASE_URL
import 'package:jwt_decoder/jwt_decoder.dart'; // Import jwt_decoder

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final String _baseUrl = '$baseUrl/api/auth'; // Base URL for auth endpoints
  final _storage = const FlutterSecureStorage();
  final String _tokenKey = 'auth_token'; // Key for storing the token

  // Login with email and password
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
        // Attempt to parse error message from backend
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Login failed with status code: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Re-throw a more generic error or the specific one from the backend
      throw Exception('Failed to login. Please check your credentials and network. Error: $e');
    }
  }

  // Sign out
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  // Register a new user
  Future<void> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'name': name, // Include name in the registration payload
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

  // Get auth token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Get user role from JWT
  Future<String?> getUserRole() async {
    final token = await getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['role']; // Assuming the role is stored in the JWT payload
    }
    return null;
  }

  // Get user name from JWT
  Future<String?> getUserName() async {
    final token = await getToken();
    if (token != null && !JwtDecoder.isExpired(token)) {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['userName']; // Assuming the name is stored as 'userName' in the JWT payload
    }
    return null;
  }


  // Check if a token is expired
  Future<bool> isTokenExpired(String token) async {
    return JwtDecoder.isExpired(token);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && !await isTokenExpired(token);
  }
}