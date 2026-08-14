import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';
import 'package:fast_food_app/widgets/gradient_widgets.dart';

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
    final Color categoryBgColor = widget.category.backgroundColorAsColor;
    final Color animationGapColor = Theme.of(context).scaffoldBackgroundColor;

    final Color cardColor = widget.isSelected ? categoryBgColor : Colors.white;
    final Color textColor = widget.isSelected ? Colors.white : Colors.black;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
        image: null,
      ),
      child: Center(
        child: Text(
          widget.category.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            shadows: widget.isSelected
                ? const [
                    Shadow(
                        blurRadius: 6,
                        color: Colors.black54,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
        ),
      ),
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedActionBorder(
          borderRadius: BorderRadius.circular(28),
          padding: widget.isSelected ? 4.0 : 3.0,
          colors: const [
            Color(0xFFFFB02E),
            Color(0xFF0E6CFF),
            Color(0xFFFF4D8D),
            Color(0xFFFFB02E),
          ],
          duration: const Duration(milliseconds: 1850),
          child: Container(
            padding: EdgeInsets.all(widget.isSelected ? 3 : 2),
            decoration: BoxDecoration(
              color: animationGapColor,
              borderRadius: BorderRadius.circular(26),
            ),
            child: card,
          ),
        ),
      ),
    );
  }
}
