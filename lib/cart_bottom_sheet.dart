import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/checkout_page.dart';
import 'package:fast_food_app/menu_customization_page.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({super.key});

  Widget _buildCustomizationDetails(CartItem cartItem, BuildContext context) {
    if (cartItem.selectedOptions.isEmpty && cartItem.ingredientsToRemove.isEmpty && cartItem.selectedSize == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailColor = isDark ? Colors.white60 : Colors.black54;

    List<Widget> details = [];

    // Display selected size first
    if (cartItem.selectedSize != null) {
      details.add(Text('• Taille: ${cartItem.selectedSize!.name}', style: TextStyle(fontSize: 12, color: detailColor)));
    }

    cartItem.selectedOptions.forEach((category, options) {
      if (options.isNotEmpty) {
        final categoryDisplay = category.replaceAll('Options', '').replaceAll('mainFillings', 'Garnitures');
        details.add(Text('• $categoryDisplay: ${options.map((opt) => opt.name).join(', ')}', style: TextStyle(fontSize: 12, color: detailColor)));
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
    final isDark = theme.brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Cart List
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    if (cart.items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                            const SizedBox(height: 20),
                            Text('Votre panier est vide !', style: TextStyle(fontSize: 18, color: isDark ? Colors.white38 : Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: cart.items.length,
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white10 : Colors.black12),
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
                                  Expanded(child: Text(cartItem.item.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                  Text('${(cartItem.totalPrice / cartItem.quantity).toStringAsFixed(2)} €', style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)),
                                ],
                              ),
                              _buildCustomizationDetails(cartItem, context),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.white38 : Colors.grey[400]), onPressed: () => cart.updateItemQuantity(cartItemKey, cartItem.quantity - 1)),
                                      Text(cartItem.quantity.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                      IconButton(icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white38 : Colors.grey[400]), onPressed: () => cart.updateItemQuantity(cartItemKey, cartItem.quantity + 1)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white38 : Colors.grey[400], size: 20),
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
                                      IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[300]), onPressed: () => cart.removeItem(cartItemKey)),
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
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10)],
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
                          Text('${cart.totalAmount.toStringAsFixed(2)} €', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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
