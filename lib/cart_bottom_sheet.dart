import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/checkout_page.dart';
import 'package:fast_food_app/menu_customization_page.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart'; // Added import

class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({super.key});

  Widget _buildCustomizationDetails(CartItem cartItem) {
    if (cartItem.selectedOptions.isEmpty && cartItem.ingredientsToRemove.isEmpty && cartItem.selectedSize == null) {
      return const SizedBox.shrink();
    }

    List<Widget> details = [];

    // Display selected size first
    if (cartItem.selectedSize != null) {
      details.add(Text('• Taille: ${cartItem.selectedSize!.name}', style: const TextStyle(fontSize: 12, color: Colors.black54)));
    }

    cartItem.selectedOptions.forEach((category, options) {
      if (options.isNotEmpty) {
        final categoryDisplay = category.replaceAll('Options', '').replaceAll('mainFillings', 'Garnitures');
        details.add(Text('• $categoryDisplay: ${options.map((opt) => opt.name).join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)));
      }
    });

    if (cartItem.ingredientsToRemove.isNotEmpty) {
      details.add(Text('• Sans: ${cartItem.ingredientsToRemove.join(', ')}', style: TextStyle(fontSize: 12, color: Colors.red[700])));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GradientText(
                      'Votre Panier',
                      style: theme.textTheme.titleLarge,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFe63199), Color(0xFFf87e12)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    const CloseButton(),
                  ],
                ),
              ),
              // Cart List
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    if (cart.items.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                            SizedBox(height: 20),
                            Text('Votre panier est vide !', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: cart.items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final cartItems = cart.items.entries.toList();
                        final cartItem = cartItems[index].value;
                        final cartItemKey = cartItems[index].key;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(cartItem.item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                  Text('${(cartItem.totalPrice / cartItem.quantity).toStringAsFixed(2)} €', style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              _buildCustomizationDetails(cartItem),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => cart.updateItemQuantity(cartItemKey, cartItem.quantity - 1)),
                                      Text(cartItem.quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      IconButton(icon: Icon(Icons.add_circle_outline, color: theme.primaryColor), onPressed: () => cart.updateItemQuantity(cartItemKey, cartItem.quantity + 1)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: theme.primaryColor, size: 20),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MenuCustomizationPage(
                                                menuItem: cartItem.item,
                                                cartItem: cartItem,
                                                cartItemKey: cartItemKey,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[700]), onPressed: () => cart.removeItem(cartItemKey)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GradientText(
                            'Total',
                            style: theme.textTheme.titleLarge,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFe63199), Color(0xFFf87e12)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          Text('${cart.totalAmount.toStringAsFixed(2)} €', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        onPressed: cart.itemCount > 0
                            ? () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutPage()));
                              }
                            : null,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9c4dea), Color(0xFFff80b1)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        text: 'Passer à la caisse',
                        icon: Icons.shopping_cart_checkout,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
