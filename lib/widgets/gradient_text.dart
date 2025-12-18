
import 'package:flutter/material.dart';

// Helper widget to apply a gradient to its child (e.g., Text or Icon).
class GradientWidget extends StatelessWidget {
  final Widget child;
  final Gradient gradient;

  const GradientWidget({
    super.key,
    required this.child,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: child,
    );
  }
}
