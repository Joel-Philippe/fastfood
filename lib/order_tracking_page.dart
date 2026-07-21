import 'dart:async';

import 'package:fast_food_app/order_model.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/services/websocket_service.dart';
import 'package:flutter/material.dart';

class OrderTrackingPage extends StatefulWidget {
  final String trackingToken;

  const OrderTrackingPage({super.key, required this.trackingToken});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final MongoService _mongoService = MongoService();
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _socketSubscription;
  Timer? _refreshTimer;

  Order? _order;
  bool _isLoading = true;
  String? _error;

  static const List<String> _steps = [
    'pending',
    'preparing',
    'ready',
    'out_for_delivery',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _connectLiveTracking();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _loadOrder(showLoader: false));
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _refreshTimer?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _loadOrder({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final order =
          await _mongoService.getOrderByTrackingToken(widget.trackingToken);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _connectLiveTracking() {
    _webSocketService.connectToOrderTracking(widget.trackingToken);
    _socketSubscription = _webSocketService.stream.listen((message) {
      if (message['type'] == 'PUBLIC_ORDER_STATUS_UPDATE' &&
          message['order'] != null) {
        final order = Order.fromMap(message['order'], message['order']['_id']);
        if (!mounted) return;
        setState(() => _order = order);
      }
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Commande reçue';
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

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'takeaway':
        return 'À emporter';
      case 'eat_in':
        return 'Sur place';
      case 'delivery':
        return 'Livraison';
      default:
        return type;
    }
  }

  int _currentStepIndex(Order order) {
    if (order.status == 'cancelled') return -1;
    final index = _steps.indexOf(order.status);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de commande'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 72),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadOrder(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return const Center(child: Text('Commande introuvable.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStep = _currentStepIndex(order);
    final paid = order.paymentStatus == 'paid';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.id.substring(order.id.length - 6)}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(order.customerName,
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                        icon: Icons.restaurant,
                        label: _orderTypeLabel(order.orderType)),
                    _InfoChip(
                        icon: Icons.euro,
                        label: '${order.totalAmount.toStringAsFixed(2)} €'),
                    _InfoChip(
                      icon: paid ? Icons.verified : Icons.schedule,
                      label: paid ? 'Paiement validé' : 'Paiement en attente',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Avancement',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                if (order.status == 'cancelled')
                  const _CancelledState()
                else
                  ..._steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final status = entry.value;
                    final isDone = index <= currentStep;
                    return _TrackingStep(
                      label: _statusLabel(status),
                      isDone: isDone,
                      isCurrent: index == currentStep,
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Articles',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...order.items.values.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.quantity}x ${item.item.name}'),
                      trailing: Text(
                          '${(item.item.price * item.quantity).toStringAsFixed(2)} €'),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Cette page se met à jour automatiquement. Vous pouvez garder ce lien ouvert sans installer l’application.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;

  const _TrackingStep({
    required this.label,
    required this.isDone,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? const Color(0xFF53c6fd) : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDone ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            child: Icon(isDone ? Icons.check : Icons.more_horiz,
                color: isDone ? Colors.white : color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? color : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledState extends StatelessWidget {
  const _CancelledState();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.cancel, color: Colors.red),
        SizedBox(width: 10),
        Expanded(child: Text('Cette commande a été annulée.')),
      ],
    );
  }
}
