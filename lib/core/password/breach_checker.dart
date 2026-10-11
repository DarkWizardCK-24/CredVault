import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Asks whether a password has appeared in a known data breach.
abstract class BreachChecker {
  /// How many times the password was seen in breaches (0 = never seen), or
  /// `null` if the check could not be completed (e.g. offline).
  Future<int?> pwnedCount(String password);
}

/// Uses the Have I Been Pwned "range" API.
///
/// Only the first 5 characters of the password's SHA-1 hash are sent
/// (k-anonymity), so neither the password nor its full hash ever leaves the
/// device.
class HibpBreachChecker implements BreachChecker {
  HibpBreachChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint = 'https://api.pwnedpasswords.com/range/';

  static Future<String> sha1Hex(String value) async {
    final hash = await Sha1().hash(utf8.encode(value));
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  @override
  Future<int?> pwnedCount(String password) async {
    if (password.isEmpty) return 0;
    try {
      final hash = await sha1Hex(password);
      final prefix = hash.substring(0, 5);
      final suffix = hash.substring(5);

      final response = await _client
          .get(
            Uri.parse('$_endpoint$prefix'),
            // Pads the response so its size doesn't hint at the result.
            headers: const {'Add-Padding': 'true'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      for (final line in const LineSplitter().convert(response.body)) {
        final parts = line.trim().split(':');
        if (parts.length == 2 && parts[0].toUpperCase() == suffix) {
          return int.tryParse(parts[1]) ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Breach check failed: $e');
      return null;
    }
  }
}
