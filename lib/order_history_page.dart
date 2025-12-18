import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/services/websocket_service.dart';
import 'package:fast_food_app/order_model.dart';
import 'package:intl/intl.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart'; // Correctly placed
import 'package:flutter_animate/flutter_animate.dart'; // Correctly placed

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final MongoService _mongoService = MongoService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();
  
  StreamSubscription? _socketSubscription;
  List<Order>? _orders;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialOrders();
    _initWebSocket();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _fetchInitialOrders() async {
    try {
      final orders = await _mongoService.getMyOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return;
      }
      
      _webSocketService.connect(token);
      
      _socketSubscription = _webSocketService.stream.listen((message) {
        if (message['type'] == 'ORDER_STATUS_UPDATE') {
          final updatedOrderData = message['order'];
          if (updatedOrderData != null && _orders != null) {
            final updatedOrder = Order.fromMap(updatedOrderData, updatedOrderData['_id']);
            setState(() {
              final index = _orders!.indexWhere((order) => order.id == updatedOrder.id);
              if (index != -1) {
                _orders![index] = updatedOrder;
              }
            });
          }
        }
      }, onError: (error) {
        debugPrint("WebSocket Stream Error: $error");
      });

    } catch (e) {
      debugPrint("Failed to initialize WebSocket: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFfcf1f1), Color(0xFFfffcdd)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: accentColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Mes Commandes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Erreur: $_error'));
    }

    if (_orders == null || _orders!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'Aucune commande trouvée',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre historique de commandes apparaîtra ici.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      );
    }

    final orders = _orders!;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        const accentColor = Color(0xFF53c6fd);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Commande #${order.id.substring(order.id.length - 6)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: accentColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.euro, color: Colors.green, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        order.totalAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.black54, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm').format(order.orderDate),
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.flag, color: Colors.black54, size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getFrenchStatus(order.status),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Articles :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              ...order.items.values.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text(
                  '${item.quantity}x ${item.item.name}',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              )),
            ],
          ),
        ).animate().fadeIn(delay: (100 * index).ms, duration: 400.ms, curve: Curves.easeOut);
      },
    );
  }

  String _getFrenchStatus(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    const accentColor = Color(0xFF53c6fd);
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return accentColor; // Use accent color
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}