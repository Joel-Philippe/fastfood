import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/services/websocket_service.dart';
import 'package:fast_food_app/order_model.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final MongoService _mongoService = MongoService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription? _socketSubscription;
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  final List<String> _orderStatuses = [
    'pending',
    'preparing',
    'ready',
    'out_for_delivery',
    'completed',
    'cancelled'
  ];

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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialOrders() async {
    try {
      final orders = await _mongoService.getOrders();
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
      if (token == null) return;

      _webSocketService.connect(token);
      _socketSubscription = _webSocketService.stream.listen((message) {
        if (message['type'] == 'NEW_ORDER') {
          final newOrder = Order.fromMap(message['order'], message['order']['_id']);
          setState(() {
            _orders.insert(0, newOrder);
          });
          _playNewOrderSound();
        } else if (message['type'] == 'ORDER_STATUS_UPDATE') {
          final updatedOrder = Order.fromMap(message['order'], message['order']['_id']);
          setState(() {
            final index = _orders.indexWhere((o) => o.id == updatedOrder.id);
            if (index != -1) {
              _orders[index] = updatedOrder;
            }
          });
        }
      });
    } catch (e) {
      debugPrint("AdminDashboard Failed to initialize WebSocket: $e");
    }
  }

  Future<void> _playNewOrderSound() async {
    await _audioPlayer.play(AssetSource('sounds/new_order.mp3'));
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _mongoService.updateOrderStatus(orderId, newStatus);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade300;
      case 'preparing':
        return Colors.blue.shade300;
      case 'ready':
        return Colors.green.shade300;
      case 'out_for_delivery':
        return Colors.purple.shade300;
      case 'completed':
        return Colors.grey.shade500;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.grey.shade400;
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'out_for_delivery':
        return 'En livraison';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  void _showStatusPicker(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFfcf1f1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Changer le statut',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
              const Divider(height: 1),
              ..._orderStatuses.map((status) => ListTile(
                title: Text(_translateStatus(status)),
                onTap: () {
                  _updateOrderStatus(order.id, status);
                  Navigator.of(context).pop();
                },
                trailing: order.status == status
                    ? Icon(Icons.check_circle, color: _getStatusColor(status))
                    : null,
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFfcf1f1), Color(0xFFfffcdd)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomAppBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    const accentColor = Color(0xFF53c6fd);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: accentColor, size: 28),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(width: 10),
          const Text(
            'Commandes en Cours',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)));
    }
    if (_error != null) {
      return Center(child: Text('Erreur: $_error'));
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_rounded, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune commande pour le moment',
              style: TextStyle(fontSize: 20, color: Colors.black54),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
      child: ExpansionTile(
        key: PageStorageKey(order.id),
        title: _buildOrderCardHeader(order),
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [_buildOrderCardDetails(order)],
      ),
    );
  }

  Widget _buildOrderCardHeader(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '#${order.id.substring(order.id.length - 6)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                '${order.totalAmount.toStringAsFixed(2)} €',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.black54),
            const SizedBox(width: 4),
            Flexible(child: Text(order.customerName, style: const TextStyle(color: Colors.black54), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatusChip(order),
      ],
    );
  }

  Widget _buildStatusChip(Order order) {
    return InkWell(
      onTap: () => _showStatusPicker(order),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(order.status).withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(backgroundColor: _getStatusColor(order.status), radius: 5),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _translateStatus(order.status),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(order.status).withRed(50).withGreen(50),
                ),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCardDetails(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...order.items.values.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('${item.quantity}x ${item.item.name}', softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
              Flexible(child: Text('${(item.totalPrice / item.quantity).toStringAsFixed(2)} €')),
            ],
          ),
        )),
        const Divider(),
        if (order.orderType == 'delivery' && order.address != null) ...[
          const Text('Adresse de livraison:', style: TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(order.address!.street, softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          Flexible(child: Text('${order.address!.postalCode} ${order.address!.city}', softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          Flexible(child: Text('Tél: ${order.address!.phone}', softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Type de commande:', style: TextStyle(color: Colors.grey)),
            Flexible(child: Text(_translateStatus(order.orderType), style: const TextStyle(fontWeight: FontWeight.bold), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Date:', style: TextStyle(color: Colors.grey)),
            Flexible(child: Text(DateFormat('dd/MM/yy HH:mm').format(order.orderDate), style: const TextStyle(fontWeight: FontWeight.bold), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
      ],
    );
  }
}