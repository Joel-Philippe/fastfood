import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fast_food_app/app_config.dart'; // To get the base URL

class WebSocketService {
  WebSocketChannel? _channel;
  final _socketResponseController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _socketResponseController.stream;

  void connect(String token) {
    // Disconnect any existing channel
    disconnect();

    // Construct WebSocket URL from AppConfig.baseUrl
    final wsUrl = Uri.parse(AppConfig.baseUrl).replace(scheme: 'ws', path: '/').toString();
    
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      debugPrint('WebSocket connected to $wsUrl');

      _channel!.stream.listen(
        (message) {
          try {
            final decodedMessage = json.decode(message) as Map<String, dynamic>;
            _socketResponseController.add(decodedMessage);
          } catch (e) {
            debugPrint('Error decoding WebSocket message: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed.');
          // Optionally, try to reconnect here
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          // Optionally, handle reconnection on error
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      debugPrint('WebSocket disconnected.');
    }
  }
}
