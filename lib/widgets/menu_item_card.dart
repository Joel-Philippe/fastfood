import 'package:fast_food_app/cart_provider.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class MenuItemCard extends StatefulWidget {
  final MenuItem item;
  final Function(BuildContext, MenuItem, Color) onAddItem;
  final int index;
  final Color cardTextColor; // New parameter for text color

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAddItem,
    required this.index,
    required this.cardTextColor, // Required new parameter
  });

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    // If there's no image, it's considered loaded immediately.
    if (widget.item.imageUrl == null || widget.item.imageUrl!.isEmpty) {
      _isImageLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? widget.cardTextColor : const Color(0xFFFFF6F1);
    final textColor = isDark ? Colors.white : Colors.black;

    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final bool isInCart = cart.isItemInCart(widget.item.id);

        return Stack(
          children: [
            AnimatedActionBorder(
              borderRadius: BorderRadius.circular(16),
              padding: 3.5,
              colors: const [
                Color(0xFFFFB02E),
                Color(0xFF0E6CFF),
                Color(0xFFFF4D8D),
                Color(0xFFFFB02E),
              ],
              duration: const Duration(milliseconds: 2600),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 8,
                color: cardColor,
                shadowColor: isDark
                    ? widget.cardTextColor.withOpacity(0.5)
                    : Colors.black.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onAddItem(
                      context, widget.item, Theme.of(context).primaryColor),
                  child: AnimatedOpacity(
                    opacity: _isImageLoaded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Image.network(
                                widget.item.imageUrl ?? '',
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted)
                                        setState(() => _isImageLoaded = true);
                                    });
                                    return child;
                                  }
                                  return Shimmer.fromColors(
                                    baseColor: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                    highlightColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey[700]!
                                            : Colors.grey[100]!,
                                    child: Container(color: cardColor),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted)
                                      setState(() => _isImageLoaded = true);
                                  });
                                  return Container(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 50, color: Colors.grey)),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // Text content
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Container(
                            constraints: const BoxConstraints(
                                minHeight: 90), // Minimum height for alignment
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Price
                                Text(
                                  '${widget.item.price.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF5B3735)),
                                ),
                                const SizedBox(height: 4),
                                // Title
                                Text(
                                  widget.item.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor),
                                  maxLines: 2, // Allow up to 2 lines for title
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Description
                                if (widget.item.description != null &&
                                    widget.item.description!.isNotEmpty)
                                  Text(
                                    widget.item.description!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: textColor,
                                        fontWeight: FontWeight.w500),
                                    maxLines:
                                        4, // Allow up to 4 lines for description
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate(delay: (50 * widget.index).ms)
                .slideY(begin: 0.5, duration: 400.ms, curve: Curves.easeOut)
                .fadeIn(),
            if (isInCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF1192ef), // #1192ef
                        Color(0xFF9761a9), // #9761a9
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: textColor,
                    size: 16,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
