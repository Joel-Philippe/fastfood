import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fast_food_app/services/auth_service.dart';
import 'package:fast_food_app/services/mongo_service.dart';
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

  // State for the status filter
  String? _selectedStatus;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'pending':
        return isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700;
      case 'preparing':
        return isDark ? const Color(0xFF64B5F6) : Colors.blue.shade700;
      case 'ready':
        return isDark ? const Color(0xFF81C784) : Colors.green.shade700;
      case 'out_for_delivery':
        return isDark ? const Color(0xFFBA68C8) : Colors.purple.shade700;
      case 'completed':
        return isDark ? Colors.white38 : Colors.grey.shade600;
      case 'cancelled':
        return isDark ? const Color(0xFFE57373) : Colors.red.shade700;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFfcf1f1),
            borderRadius: const BorderRadius.only(
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
                    color: isDark ? Colors.white70 : Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              ..._orderStatuses.map((status) => ListTile(
                title: Text(_translateStatus(status), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF121212), const Color(0xFF1E1E1E)]
                : [const Color(0xFFfcf1f1), const Color(0xFFfffcdd)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomAppBar(),
              _buildFilterChips(),
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

  Widget _buildFilterChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String?> filterOptions = [null, ..._orderStatuses];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 10.0),
      child: Row(
        children: filterOptions.map((status) {
          final isSelected = _selectedStatus == status;
          final label = status == null ? 'Toutes' : _translateStatus(status);
          final color = status == null ? Colors.blueGrey : _getStatusColor(status);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedStatus = status;
                  });
                }
              },
              selectedColor: color.withOpacity(0.7),
              backgroundColor: color.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF53c6fd)));
    }
    if (_error != null) {
      return Center(child: Text('Erreur: $_error', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }

    final List<Order> filteredOrders;
    if (_selectedStatus == null) {
      filteredOrders = _orders;
    } else {
      filteredOrders = _orders.where((order) => order.status == _selectedStatus).toList();
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_rounded, size: 80, color: isDark ? Colors.grey[800] : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == null ? 'Aucune commande pour le moment' : 'Aucune commande avec le statut "${_translateStatus(_selectedStatus!)}"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: isDark ? Colors.white38 : Colors.black54),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;
        
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: constraints.maxWidth > 900 ? 1.8 : 1.3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            return _buildOrderCard(order);
          },
        );
      }
    );
  }

  Widget _buildOrderCard(Order order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(order.id),
          title: _buildOrderCardHeader(order),
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [_buildOrderCardDetails(order)],
        ),
      ),
    );
  }

  Widget _buildOrderCardHeader(Order order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '#${order.id.substring(order.id.length - 6)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                '${order.totalAmount.toStringAsFixed(2)} €',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person_outline, size: 16, color: isDark ? Colors.white60 : Colors.black54),
            const SizedBox(width: 4),
            Flexible(child: Text(order.customerName, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                  color: _getStatusColor(order.status),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: isDark ? Colors.white10 : Colors.black12),
        Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ...order.items.values.map((cartItem) {
          Widget buildDetailRow(String text, {bool isRemoval = false}) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRemoval ? '– ' : '+ ', style: TextStyle(color: isRemoval ? Colors.red : Colors.green, fontSize: 14)),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          List<Widget> details = [];
          cartItem.selectedOptions.forEach((category, options) {
            for (var option in options) {
              details.add(buildDetailRow('${option.name} (${option.price.toStringAsFixed(2)}€)'));
            }
          });
          for (var ingredient in cartItem.ingredientsToRemove) {
            details.add(buildDetailRow('Sans $ingredient', isRemoval: true));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cartItem.quantity}x ${cartItem.item.name}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details,
                    ),
                  ),
              ],
            ),
          );
        }),
        Divider(color: isDark ? Colors.white10 : Colors.black12),
        if (order.orderType == 'delivery' && order.address != null) ...[
          Text('Adresse de livraison:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Flexible(child: Text(order.address!.street, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          Flexible(child: Text('${order.address!.postalCode} ${order.address!.city}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          Flexible(child: Text('Tél: ${order.address!.phone}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Type de commande:', style: TextStyle(color: secondaryTextColor)),
            Flexible(child: Text(_translateStatus(order.orderType), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Date:', style: TextStyle(color: secondaryTextColor)),
            Flexible(child: Text(DateFormat('dd/MM/yy HH:mm').format(order.orderDate), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), softWrap: false, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
      ],
    );
  }
}
