import 'dart:math';

enum StrengthLevel {
  veryWeak('Very weak'),
  weak('Weak'),
  fair('Fair'),
  strong('Strong'),
  excellent('Excellent');

  final String label;

  const StrengthLevel(this.label);

  /// 0 - 4
  int get score => index;

  bool get isWeak => this == veryWeak || this == weak;
}

class PasswordStrength {
  final StrengthLevel level;

  /// Estimated entropy in bits (after penalties for obvious patterns).
  final double bits;

  /// Short, actionable hints for improving the password.
  final List<String> hints;

  const PasswordStrength({
    required this.level,
    required this.bits,
    required this.hints,
  });

  /// A rough, human-friendly "time to guess" at ten billion guesses a second.
  String get crackTime {
    final seconds = pow(2, max(bits - 1, 0)) / 1e10;
    if (seconds < 1) return 'instantly';
    if (seconds < 60) return '${seconds.floor()} seconds';
    final minutes = seconds / 60;
    if (minutes < 60) return '${minutes.floor()} minutes';
    final hours = minutes / 60;
    if (hours < 24) return '${hours.floor()} hours';
    final days = hours / 24;
    if (days < 60) return '${days.floor()} days';
    final years = days / 365;
    if (years < 1) return '${(days / 30).floor()} months';
    if (years < 1000) return '${years.floor()} years';
    if (years < 1e6) return 'thousands of years';
    return 'millions of years';
  }
}

/// A fast, offline strength estimate: character variety and length, with
/// penalties for repeats, simple sequences and well-known passwords.
class PasswordStrengthEstimator {
  PasswordStrengthEstimator._();

  static const List<String> _common = [
    'password',
    'passw0rd',
    '123456',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty',
    'qwertyuiop',
    'abc123',
    'letmein',
    'welcome',
    'admin',
    'iloveyou',
    'monkey',
    'dragon',
    'football',
    'baseball',
    'sunshine',
    'princess',
    'login',
    'master',
    'hello',
    'freedom',
    'whatever',
    'trustno1',
    'secret',
    'shadow',
    'superman',
    'batman',
    'changeme',
    'default',
    'guest',
    '000000',
    '111111',
    '121212',
    '654321',
    'asdfgh',
    'zxcvbn',
    'pass',
  ];

  static const List<String> _sequences = [
    'abcdefghijklmnopqrstuvwxyz',
    '0123456789',
    'qwertyuiopasdfghjklzxcvbnm',
  ];

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        level: StrengthLevel.veryWeak,
        bits: 0,
        hints: ['Enter a password'],
      );
    }

    final hints = <String>[];
    final lower = password.toLowerCase();

    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) pool += 10;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) pool += 33;

    var bits = password.length * (log(max(pool, 2)) / ln2);

    // Repeated characters add little (aaaa, 1111): scale the estimate by how
    // many *different* characters there are.
    final unique = password.split('').toSet().length;
    final variety = unique / password.length;
    if (variety < 0.6) {
      bits *= max(0.25, variety);
      hints.add('Avoid repeating the same characters');
    }

    // Runs like abcd, 4321 or qwer.
    if (_hasSequence(lower, 4)) {
      bits -= 12;
      hints.add('Avoid simple sequences like "abcd" or "1234"');
    }

    // Well-known passwords, even with a few extra characters.
    for (final word in _common) {
      if (lower.contains(word)) {
        bits = min(bits, 20) - (lower == word ? 10 : 0);
        hints.add('Avoid common words and passwords');
        break;
      }
    }

    if (password.length < 12) hints.add('Use at least 12 characters');
    if (pool < 62 && password.length < 16) {
      hints.add('Mix upper and lower case letters, numbers and symbols');
    }

    bits = max(0, bits);
    final level = bits < 28
        ? StrengthLevel.veryWeak
        : bits < 40
        ? StrengthLevel.weak
        : bits < 60
        ? StrengthLevel.fair
        : bits < 80
        ? StrengthLevel.strong
        : StrengthLevel.excellent;

    return PasswordStrength(
      level: level,
      bits: bits,
      hints: level == StrengthLevel.excellent ? const [] : hints,
    );
  }

  static bool _hasSequence(String s, int run) {
    for (final seq in _sequences) {
      final reversed = seq.split('').reversed.join();
      for (var i = 0; i + run <= s.length; i++) {
        final part = s.substring(i, i + run);
        if (seq.contains(part) || reversed.contains(part)) return true;
      }
    }
    return false;
  }
}
