import 'package:fast_food_app/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/order_confirmation_page.dart';
import 'package:fast_food_app/order_model.dart' as AppModels; // Import Order model and our Address class with a prefix
import 'package:fast_food_app/services/mongo_service.dart'; // Import MongoService
import 'dart:math'; // For generating a random order ID
import 'package:flutter_stripe/flutter_stripe.dart' hide Address; // Import Flutter Stripe and hide its Address to avoid conflict
import 'dart:convert'; // For json.encode/decode
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:fast_food_app/widgets/gradient_widgets.dart';
import 'package:fast_food_app/services/auth_service.dart'; // Import AuthService

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  String _orderType = 'takeaway'; // 'takeaway', 'eat_in', or 'delivery'
  TimeOfDay? _arrivalTime;
  final MongoService _mongoService = MongoService(); // Instantiate MongoService
  final AuthService _authService = AuthService(); // Instantiate AuthService

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userName = await _authService.getUserName();
    if (userName != null && userName.isNotEmpty) {
      setState(() {
        _nameController.text = userName;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _arrivalTime) {
      setState(() {
        _arrivalTime = picked;
      });
    }
  }

  Future<void> _initiatePayment(CartProvider cart) async {
    if (!_formKey.currentState!.validate()) {
      return; // Form is not valid
    }

    try {
      // 1. Call our backend to create a Payment Intent
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/stripe/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': (cart.totalAmount * 100).toInt(), // Amount in cents
          'currency': 'eur',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment intent: ${response.body}');
      }

      final responseBody = json.decode(response.body);
      final clientSecret = responseBody['clientSecret'];

      if (clientSecret == null) {
        throw Exception('Client secret not received from backend.');
      }

      // 2. Initialize the Payment Sheet
      if (!mounted) return;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Fast Food App',
          style: Theme.of(context).brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        ),
      );

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // If payment is successful, proceed to place the order
      await _placeOrder(cart);

    } on StripeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Error: ${e.error.localizedMessage}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _placeOrder(CartProvider cart) async {
    // The form is already validated in _initiatePayment
    final orderId = (Random().nextInt(900000) + 100000).toString();

    final newOrder = AppModels.Order(
      id: orderId,
      customerName: _nameController.text,
      orderType: _orderType,
      arrivalTime: _orderType == 'eat_in' ? _arrivalTime?.format(context) : null,
      items: Map.from(cart.items),
      totalAmount: cart.totalAmount,
      orderDate: DateTime.now(),
      status: 'pending',
      address: _orderType == 'delivery'
          ? AppModels.Address(
              street: _streetController.text,
              city: _cityController.text,
              postalCode: _postalCodeController.text,
              phone: _phoneController.text,
            )
          : null,
    );

    try {
      await _mongoService.placeOrder(newOrder);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande passée avec succès !')),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationPage(
            orderId: newOrder.id,
            customerName: newOrder.customerName,
            orderType: newOrder.orderType,
            arrivalTime: newOrder.arrivalTime,
            orderItems: newOrder.items,
            totalAmount: newOrder.totalAmount,
          ),
        ),
        (route) => route.isFirst,
      );

      cart.clearCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la commande : $e')),
      );
    }
  }

  Widget _buildOrderTypeChip(String label, String value, IconData icon) {
    final bool isSelected = _orderType == value;
    final Color selectedColor = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orderType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF53c6fd) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF53c6fd) : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF53c6fd).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const GradientIcon(
            Icons.arrow_back,
            size: 24,
            gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const GradientText(
          'Paiement',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Votre nom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre nom.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const GradientText(
              'Type de commande :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOrderTypeChip('À emporter', 'takeaway', Icons.shopping_bag_outlined),
                _buildOrderTypeChip('Sur place', 'eat_in', Icons.local_dining_outlined),
                _buildOrderTypeChip('Livraison', 'delivery', Icons.delivery_dining_outlined),
              ],
            ),
            const SizedBox(height: 20),
            if (_orderType == 'eat_in')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text('Heure d\'arrivée :', style: TextStyle(fontSize: 16)),
                  ListTile(
                    title: Text(_arrivalTime == null ? 'Sélectionner l\'heure' : _arrivalTime!.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(context),
                  ),
                ],
              ),
            if (_orderType == 'delivery')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const GradientText(
                    'Adresse de livraison :',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(labelText: 'Rue et numéro', border: OutlineInputBorder()),
                    validator: (value) {
                      if (_orderType == 'delivery' && (value == null || value.isEmpty)) {
                        return 'Veuillez entrer votre rue.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ville', border: OutlineInputBorder()),
                    validator: (value) {
                      if (_orderType == 'delivery' && (value == null || value.isEmpty)) {
                        return 'Veuillez entrer votre ville.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'Code Postal', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_orderType == 'delivery' && (value == null || value.isEmpty)) {
                        return 'Veuillez entrer votre code postal.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Numéro de téléphone', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (_orderType == 'delivery' && (value == null || value.isEmpty)) {
                        return 'Veuillez entrer votre numéro de téléphone.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            const SizedBox(height: 20),
            const GradientText(
              'Résumé de la commande :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final cartItem = cart.items.values.toList()[index];

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
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GradientText(
                  'Total :',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  gradient: LinearGradient(
              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
                ),
                Text('${cart.totalAmount.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: cart.itemCount > 0 ? () => _initiatePayment(cart) : null,
              gradient: const LinearGradient(
                colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              text: 'Payer et passer la commande',
              icon: Icons.credit_card,
            ),
          ],
        ),
      ),
    );
  }
}

