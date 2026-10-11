import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Thrown when data can't be decrypted (wrong key or tampered data).
class VaultDecryptException implements Exception {
  final String message;

  const VaultDecryptException([this.message = 'Could not decrypt the data']);

  @override
  String toString() => message;
}

/// The parameters needed to re-derive a vault key from the master password.
class KdfParams {
  final List<int> salt;
  final int iterations;

  const KdfParams({required this.salt, required this.iterations});
}

/// Everything cryptographic in CredVault lives here.
///
/// * The vault key is derived from the master password with PBKDF2-HMAC-SHA256
///   and a random per-user salt. The master password never leaves the device.
/// * Every credential is encrypted with AES-256-GCM using a fresh random nonce.
///   GCM also authenticates the data, so tampering is detected.
/// * Payloads are stored as `base64(nonce | ciphertext | tag)`.
class VaultCrypto {
  const VaultCrypto({
    this.iterations = defaultIterations,
    this.useIsolate = true,
  });

  /// Work factor for new vaults. It is stored with each vault, so it can be
  /// raised later without breaking existing ones.
  static const int defaultIterations = 200000;
  static const int saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const String _verifierText = 'credvault-vault-v1';

  final int iterations;

  /// Run key derivation on a background isolate so the UI stays smooth.
  /// (Tests turn this off: a real isolate can't run inside fake-async time.)
  final bool useIsolate;

  static final AesGcm _aes = AesGcm.with256bits();

  static List<int> randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  KdfParams newKdfParams() =>
      KdfParams(salt: randomBytes(saltLength), iterations: iterations);

  /// Derives the vault key. The heavy work runs on a background isolate.
  Future<SecretKey> deriveKey(String masterPassword, KdfParams params) async {
    final request = _DeriveRequest(
      masterPassword,
      params.salt,
      params.iterations,
    );
    final bytes = useIsolate
        ? await compute(_deriveKeyBytes, request)
        : await _deriveKeyBytes(request);
    return SecretKey(bytes);
  }

  Future<String> encrypt(SecretKey key, String plaintext) async {
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return base64Encode(box.concatenation());
  }

  Future<String> decrypt(SecretKey key, String payload) async {
    try {
      final bytes = base64Decode(payload);
      if (bytes.length < _nonceLength + _macLength) {
        throw const VaultDecryptException('The data is too short');
      }
      final box = SecretBox.fromConcatenation(
        bytes,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      return utf8.decode(await _aes.decrypt(box, secretKey: key));
    } on VaultDecryptException {
      rethrow;
    } catch (_) {
      throw const VaultDecryptException();
    }
  }

  /// A small encrypted sentence stored with the vault so a wrong master
  /// password can be detected without touching any credential.
  Future<String> makeVerifier(SecretKey key) => encrypt(key, _verifierText);

  Future<bool> checkVerifier(SecretKey key, String verifier) async {
    try {
      return await decrypt(key, verifier) == _verifierText;
    } on VaultDecryptException {
      return false;
    }
  }
}

class _DeriveRequest {
  final String password;
  final List<int> salt;
  final int iterations;

  const _DeriveRequest(this.password, this.salt, this.iterations);
}

Future<List<int>> _deriveKeyBytes(_DeriveRequest request) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: request.iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKeyFromPassword(
    password: request.password,
    nonce: request.salt,
  );
  return key.extractBytes();
}
