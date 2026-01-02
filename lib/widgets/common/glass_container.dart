import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double blur;
  final double borderOpacity;
  final Color? borderColor;
  final BoxBorder? border; // Added support for custom border
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(15),
    this.margin = EdgeInsets.zero,
    this.blur = 10,
    this.borderOpacity = 0.1,
    this.color,
    this.gradient,
    this.onTap,
    this.borderColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.05),
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: (borderColor ?? Colors.white)
                        .withOpacity(borderOpacity),
                    width: 1.0,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
