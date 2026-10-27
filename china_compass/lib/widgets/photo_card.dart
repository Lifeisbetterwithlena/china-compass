import 'dart:ui';

import 'package:flutter/material.dart';

/// Background photo per path (see CREDITS.md for sources).
String photoFor(String personaId) => 'assets/images/$personaId.jpg';

/// Dark gradient so white text stays readable on any photo.
const photoScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.35, 1.0],
  colors: [Color(0x33000000), Color(0x00000000), Color(0xD9000000)],
);

/// Frosted-glass container for chips and buttons placed on photos.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 999, this.padding = EdgeInsets.zero});

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: child,
          ),
        ),
      );
}

/// Circular glass button for use on photos (e.g. search).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Glass(
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      );
}
