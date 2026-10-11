import 'package:cred_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum ButtonStyleKind { primary, secondary, danger }

/// Full-width action button. The primary style is the gold gradient.
class CustomButton extends StatelessWidget {
  final String text;

  /// `null` (or [isLoading]) disables the button.
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonStyleKind kind;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.kind = ButtonStyleKind.primary,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final primary = kind == ButtonStyleKind.primary;
    final color = switch (kind) {
      ButtonStyleKind.primary => AppTheme.background,
      ButtonStyleKind.secondary => AppTheme.textPrimary,
      ButtonStyleKind.danger => AppTheme.danger,
    };

    final label = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: text,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: primary ? AppTheme.goldGradient : null,
              color: primary ? null : AppTheme.surfaceHigh,
              border: primary
                  ? null
                  : Border.all(
                      color: kind == ButtonStyleKind.danger
                          ? AppTheme.danger.withValues(alpha: 0.6)
                          : AppTheme.border,
                    ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _enabled ? onPressed : null,
              child: Center(child: label),
            ),
          ),
        ),
      ),
    );
  }
}
