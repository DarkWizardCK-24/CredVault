import 'dart:math';

/// Options for [PasswordGenerator.generate].
class GeneratorOptions {
  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;

  /// Leave out look-alike characters such as `O`, `0`, `l`, `1` and `I`.
  final bool avoidAmbiguous;

  const GeneratorOptions({
    this.length = 20,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
    this.avoidAmbiguous = false,
  });

  GeneratorOptions copyWith({
    int? length,
    bool? lowercase,
    bool? uppercase,
    bool? digits,
    bool? symbols,
    bool? avoidAmbiguous,
  }) => GeneratorOptions(
    length: length ?? this.length,
    lowercase: lowercase ?? this.lowercase,
    uppercase: uppercase ?? this.uppercase,
    digits: digits ?? this.digits,
    symbols: symbols ?? this.symbols,
    avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
  );

  bool get hasAnyClass => lowercase || uppercase || digits || symbols;
}

/// Random password generator backed by a cryptographically secure source.
class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const String _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digits = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{};:,.?';
  static const String _ambiguous = 'O0oIl1|';

  static const int minLength = 8;
  static const int maxLength = 64;

  List<String> _classes(GeneratorOptions o) {
    String strip(String chars) => o.avoidAmbiguous
        ? chars.split('').where((c) => !_ambiguous.contains(c)).join()
        : chars;
    return [
      if (o.lowercase) strip(_lower),
      if (o.uppercase) strip(_upper),
      if (o.digits) strip(_digits),
      if (o.symbols) _symbols,
    ];
  }

  /// Generates a password that always contains at least one character from
  /// every selected class. Throws [ArgumentError] if no class is selected.
  String generate(GeneratorOptions options) {
    final classes = _classes(options);
    if (classes.isEmpty) {
      throw ArgumentError('Select at least one kind of character');
    }
    final length = options.length.clamp(
      max(minLength, classes.length),
      maxLength,
    );
    final all = classes.join();

    final chars = <String>[
      // One from each class first, so every requirement is met...
      for (final c in classes) c[_random.nextInt(c.length)],
      // ...then fill up from the whole pool.
      for (var i = classes.length; i < length; i++)
        all[_random.nextInt(all.length)],
    ];

    // Fisher-Yates shuffle so the guaranteed characters aren't always first.
    for (var i = chars.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }
}
