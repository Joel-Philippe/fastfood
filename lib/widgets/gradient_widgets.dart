import 'dart:math';

import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.textAlign, // Add textAlign parameter
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign; // Declare textAlign

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        textAlign: textAlign, // Pass textAlign to the Text widget
      ),
    );
  }
}

class AnimatedGradientText extends StatefulWidget {
  const AnimatedGradientText(
    this.text, {
    super.key,
    this.gradient,
    this.colors,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.duration = const Duration(milliseconds: 2600),
  }) : assert(gradient != null || colors != null,
            'Provide either gradient or colors.');

  final String text;
  final Gradient? gradient;
  final List<Color>? colors;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration duration;

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final gradient = widget.gradient;
        final colors = gradient?.colors ?? widget.colors!;
        final stops = gradient?.stops ??
            List<double>.generate(
              colors.length,
              (index) => colors.length == 1 ? 1 : index / (colors.length - 1),
            );
        final slide = _controller.value * 2 - 1;

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: colors,
            stops: stops,
            begin: Alignment(-1 + slide, -0.35),
            end: Alignment(1 + slide, 0.35),
            tileMode: TileMode.mirror,
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }
}

class GradientIcon extends StatelessWidget {
  const GradientIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.gradient,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Icon(icon, size: size),
    );
  }
}

class AnimatedActionBorder extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final List<Color> colors;
  final double padding;
  final Duration duration;

  const AnimatedActionBorder({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.colors = const [
      Color(0xFF00A896),
      Color(0xFFFF6B35),
      Color(0xFF19D66B),
      Color(0xFF00A896),
    ],
    this.padding = 2,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<AnimatedActionBorder> createState() => _AnimatedActionBorderState();
}

class _AnimatedActionBorderState extends State<AnimatedActionBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(widget.padding),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 2 * pi),
              colors: widget.colors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    this.child,
    required this.gradient,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(vertical: 16), // Adjusted padding
    this.borderRadius = 12.0, // Adjusted borderRadius
    this.text,
    this.icon,
    this.backgroundColor,
    this.foregroundGradient,
    this.animateText = false,
  }) : assert(child != null || (text != null && icon != null),
            'Either a child or both text and icon must be provided.');

  final Widget? child;
  final Gradient gradient;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final String? text;
  final IconData? icon;
  final Color? backgroundColor;
  final Gradient? foregroundGradient;
  final bool animateText;

  @override
  Widget build(BuildContext context) {
    final textGradient = foregroundGradient ?? gradient;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: backgroundColor == null ? gradient : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: textGradient.colors.first.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: Center(
              child: child ??
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // ADD THIS
                    children: [
                      animateText
                          ? GradientIcon(icon!,
                              size: 24, gradient: textGradient)
                          : Icon(icon!, color: Colors.white),
                      const SizedBox(width: 10),
                      animateText
                          ? AnimatedGradientText(
                              text!,
                              gradient: textGradient,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              text!,
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
