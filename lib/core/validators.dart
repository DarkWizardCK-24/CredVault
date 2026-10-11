import 'package:cred_vault/core/password/password_strength.dart';

/// Form validators shared by the screens. Each returns an error message, or
/// `null` when the value is fine.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static const int minMasterLength = 10;

  static String? required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Please enter your email';
    if (!_email.hasMatch(text)) return 'Please enter a valid email';
    return null;
  }

  /// The account (sign-in) password. Firebase requires at least 6 characters.
  static String? accountPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  /// The master password protects every secret, so it must be strong.
  static String? masterPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please choose a master password';
    }
    if (value.length < minMasterLength) {
      return 'Use at least $minMasterLength characters';
    }
    if (PasswordStrengthEstimator.evaluate(value).level.isWeak) {
      return 'That is too easy to guess. Try a longer phrase.';
    }
    return null;
  }

  static String? Function(String?) matches(
    String Function() other,
    String message,
  ) =>
      (value) => value == other() ? null : message;

  static String? url(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // optional
    final withScheme = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      return 'Enter a valid web address';
    }
    return null;
  }
}
