import 'package:flutter/material.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/order_model.dart' as AppModels;
import 'package:fast_food_app/services/mongo_service.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String orderId;
  // Note: These parameters are now optional as we load data from DB
  final String? customerName;
  final String? orderType;
  final String? arrivalTime;
  final Map<String, CartItem>? orderItems;
  final double? totalAmount;

  const OrderConfirmationPage({
    super.key,
    required this.orderId,
    this.customerName,
    this.orderType,
    this.arrivalTime,
    this.orderItems,
    this.totalAmount,
  });

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  late Future<AppModels.Order?> _orderFuture;
  final MongoService _mongoService = MongoService();

  @override
  void initState() {
    super.initState();
    _orderFuture = _loadOrder();
  }

  Future<AppModels.Order?> _loadOrder() async {
    try {
      final orders = await _mongoService.getOrders();
      // Find the order by its custom ID (the 6-digit one)
      return orders.firstWhere((o) => o.id == widget.orderId);
    } catch (e) {
      debugPrint('Error loading order for confirmation: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmation de commande'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: FutureBuilder<AppModels.Order?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = snapshot.data;
          
          // Use data from snapshot if available, otherwise fallback to widget params (if provided)
          final displayOrderId = order?.id ?? widget.orderId;
          final displayCustomerName = order?.customerName ?? widget.customerName ?? "Client";
          final displayOrderType = order?.orderType ?? widget.orderType ?? "takeaway";
          final displayArrivalTime = order?.arrivalTime ?? widget.arrivalTime;
          final displayItems = order?.items ?? widget.orderItems ?? {};
          final displayTotal = order?.totalAmount ?? widget.totalAmount ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Merci pour votre commande !',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('ID de commande : $displayOrderId', style: const TextStyle(fontSize: 18)),
                Text('Nom du client : $displayCustomerName', style: const TextStyle(fontSize: 18)),
                Text('Type de commande : ${displayOrderType == 'takeaway' ? 'À emporter' : displayOrderType == 'delivery' ? 'Livraison' : 'Sur place'}', style: const TextStyle(fontSize: 18)),
                if (displayArrivalTime != null) Text('Heure d\'arrivée : $displayArrivalTime', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                const Text('Résumé de la commande :', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = displayItems.values.toList()[index];

                      // Helper to build rows for options and ingredients
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
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
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                '${cartItem.quantity}x ${cartItem.item.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(
                                '${(cartItem.item.price * cartItem.quantity).toStringAsFixed(2)} €',
                              ),
                            ),
                            if (details.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 0, bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: details,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total :', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('${displayTotal.toStringAsFixed(2)} €', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Retour à l\'accueil'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
