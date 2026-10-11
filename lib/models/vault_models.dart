import 'dart:convert';

import 'package:cred_vault/core/crypto/vault_crypto.dart';

/// The non-secret data needed to unlock a vault. Stored with the user profile.
class VaultMeta {
  final List<int> salt;
  final int iterations;

  /// An encrypted known sentence: decrypting it proves the master password.
  final String verifier;

  /// Set once credentials from older (plaintext) versions were encrypted.
  final bool legacyMigrated;

  const VaultMeta({
    required this.salt,
    required this.iterations,
    required this.verifier,
    this.legacyMigrated = false,
  });

  KdfParams get kdf => KdfParams(salt: salt, iterations: iterations);

  VaultMeta copyWith({bool? legacyMigrated}) => VaultMeta(
    salt: salt,
    iterations: iterations,
    verifier: verifier,
    legacyMigrated: legacyMigrated ?? this.legacyMigrated,
  );

  Map<String, dynamic> toMap() => {
    'v': 1,
    'salt': base64Encode(salt),
    'iterations': iterations,
    'verifier': verifier,
    'legacyMigrated': legacyMigrated,
  };

  static VaultMeta? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final salt = map['salt'] as String?;
    final verifier = map['verifier'] as String?;
    final iterations = (map['iterations'] as num?)?.toInt();
    if (salt == null || verifier == null || iterations == null) return null;
    return VaultMeta(
      salt: base64Decode(salt),
      iterations: iterations,
      verifier: verifier,
      legacyMigrated: map['legacyMigrated'] as bool? ?? false,
    );
  }
}

/// A credential as stored on the server: only [data] is secret, and it is
/// encrypted. [legacy] holds the plaintext fields of records written by older
/// versions (so they can be encrypted).
class EncryptedRecord {
  final String id;
  final String? data;
  final Map<String, dynamic>? legacy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EncryptedRecord({
    required this.id,
    this.data,
    this.legacy,
    required this.createdAt,
    required this.updatedAt,
  });
}
