import 'package:cred_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Page background: midnight gradient with a faint gold glow in the corner.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -1.0),
            radius: 1.1,
            colors: [AppTheme.blue.withValues(alpha: 0.13), Colors.transparent],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The card surface used throughout the app: a softly lit panel with a thin
/// border (kept cheap to draw, unlike a blurred glass effect).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: shape,
          border: Border.all(color: borderColor ?? AppTheme.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceHigh.withValues(alpha: 0.85),
              AppTheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
