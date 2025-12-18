import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';

class CategoryCardWidget extends StatefulWidget {
  final MenuCategory category;
  final bool isSelected;
  final Function(MenuCategory) onTap;
  final IconData? fallbackIcon;

  const CategoryCardWidget({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.fallbackIcon,
  });

  @override
  State<CategoryCardWidget> createState() => _CategoryCardWidgetState();
}

class _CategoryCardWidgetState extends State<CategoryCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    _controller.forward();
    await Future.delayed(_controller.duration!);
    _controller.reverse();
    widget.onTap(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.category.backgroundImageUrl != null &&
        widget.category.backgroundImageUrl!.isNotEmpty;

    final Color categoryBgColor = widget.category.backgroundColorAsColor;

    // Define colors for the no-image state
    final Color cardColor;
    final Color textColor;
    if (widget.isSelected) {
      cardColor = categoryBgColor;
      textColor = Colors.white;
    } else {
      cardColor = Colors.white;
      textColor = categoryBgColor;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: !hasImage ? cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25), // Softer, more rounded corners
            border: Border.all(
              color: widget.isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              width: widget.isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected ? categoryBgColor.withOpacity(0.6) : Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
            image: hasImage
                ? DecorationImage(
                    image: NetworkImage(widget.category.backgroundImageUrl!),
                    fit: BoxFit.cover,
                    // Use the category's color for the overlay, making it lighter and more distinct
                    colorFilter: ColorFilter.mode(
                      categoryBgColor.withOpacity(0.6),
                      BlendMode.darken,
                    ),
                  )
                : null,
          ),
          child: Center(
            child: Text(
              widget.category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasImage ? Colors.white : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                // A more pronounced shadow to ensure readability on all backgrounds/images
                shadows: const [
                  Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(0, 1))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}