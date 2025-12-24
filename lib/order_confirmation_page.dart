import 'package:flutter/material.dart';
import 'package:fast_food_app/cart_provider.dart';

class OrderConfirmationPage extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String orderType;
  final String? arrivalTime;
  final Map<String, CartItem> orderItems;
  final double totalAmount;

  const OrderConfirmationPage({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.orderType,
    this.arrivalTime,
    required this.orderItems,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmation de commande'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merci pour votre commande !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('ID de commande : $orderId', style: const TextStyle(fontSize: 18)),
            Text('Nom du client : $customerName', style: const TextStyle(fontSize: 18)),
            Text('Type de commande : ${orderType == 'takeaway' ? 'À emporter' : 'Sur place'}', style: const TextStyle(fontSize: 18)),
            if (arrivalTime != null) Text('Heure d\'arrivée : $arrivalTime', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text('Résumé de la commande :', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: orderItems.length,
                itemBuilder: (context, index) {
                  final cartItem = orderItems.values.toList()[index];

                  // Helper to build rows for options and ingredients
                  Widget buildDetailRow(String text, {bool isRemoval = false}) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2), // Indent details
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isRemoval ? '– ' : '+ ', style: TextStyle(color: isRemoval ? Colors.red : Colors.green, fontSize: 14)),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
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

                  // Add selected options
                  cartItem.selectedOptions.forEach((category, options) {
                    for (var option in options) {
                      details.add(buildDetailRow('${option.name} (${option.price.toStringAsFixed(2)}€)'));
                    }
                  });

                  // Add excluded ingredients
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
                Text('${totalAmount.toStringAsFixed(2)} €', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst); // Go back to home
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
      ),
    );
  }
}
