import 'package:cred_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// One place for every snackbar so they look and behave the same.
class SnackBarHelper {
  SnackBarHelper._();

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    color: AppTheme.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showError(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.error_rounded,
    color: AppTheme.danger,
    duration: const Duration(seconds: 5),
  );

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, icon: Icons.info_rounded, color: AppTheme.gold);

  /// Like [showSuccess] but for a messenger captured before an `await`, so
  /// it can still be used after the screen that started it has closed.
  static void showSuccessOn(
    ScaffoldMessengerState messenger,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _present(
    messenger,
    message,
    icon: Icons.check_circle_rounded,
    color: AppTheme.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    _present(
      ScaffoldMessenger.of(context),
      message,
      icon: icon,
      color: color,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void _present(
    ScaffoldMessengerState messenger,
    String message, {
    required IconData icon,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: AppTheme.gold,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }
}
