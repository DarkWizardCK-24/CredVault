import 'dart:async';

import 'package:cred_vault/core/crypto/vault_crypto.dart';
import 'package:cred_vault/core/password/breach_checker.dart';
import 'package:cred_vault/core/security_report.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/models/platform_catalog.dart';
import 'package:cred_vault/models/user_model.dart';
import 'package:cred_vault/models/vault_models.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/services/vault_repository.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

enum VaultStatus {
  /// Nobody is signed in.
  signedOut,

  /// Reading the profile and vault settings.
  loading,

  /// Signed in, but the account has no vault yet (needs a master password).
  needsSetup,

  /// Signed in; the master password is needed to unlock.
  locked,

  /// Unlocked: credentials are decrypted in memory.
  unlocked,

  /// The profile or vault settings could not be loaded.
  error,
}

/// The wrong master password was entered.
class WrongMasterPassword implements Exception {
  const WrongMasterPassword();

  @override
  String toString() => 'Incorrect master password';
}

/// Owns the vault: its lock state, the decrypted credentials (in memory only)
/// and every operation on them.
class VaultProvider extends ChangeNotifier {
  VaultProvider({
    required this.repository,
    this.crypto = const VaultCrypto(),
    BreachChecker? breachChecker,
    DateTime Function()? clock,
  }) : _breachChecker = breachChecker,
       _clock = clock ?? DateTime.now;

  final VaultRepository repository;
  final VaultCrypto crypto;
  final BreachChecker? _breachChecker;
  final DateTime Function() _clock;

  VaultStatus _status = VaultStatus.signedOut;
  UserModel? _profile;
  VaultMeta? _meta;
  SecretKey? _key;
  String? _uid;
  bool _registering = false;
  StreamSubscription<List<EncryptedRecord>>? _subscription;
  int _applySequence = 0;

  List<Credential> _items = const [];
  bool _itemsLoaded = false;
  int _undecryptable = 0;

  Set<String> _breachedIds = {};
  DateTime? _breachCheckedAt;
  bool _checkingBreaches = false;
  bool _breachCheckIncomplete = false;

  String? loadError;

  // ---- read-only state ----

  VaultStatus get status => _status;
  UserModel? get profile => _profile;
  List<Credential> get items => _items;
  bool get itemsLoaded => _itemsLoaded;

  /// Records that could not be decrypted (damaged or from another key).
  int get undecryptableCount => _undecryptable;
  bool get isUnlocked => _status == VaultStatus.unlocked;
  DateTime get now => _clock();

  Set<String> get breachedIds => _breachedIds;
  DateTime? get breachCheckedAt => _breachCheckedAt;
  bool get checkingBreaches => _checkingBreaches;
  bool get breachCheckIncomplete => _breachCheckIncomplete;
  bool get canCheckBreaches => _breachChecker != null;

  SecurityReport get report =>
      SecurityReport.from(_items, now: _clock(), breachedIds: _breachedIds);

  // ---- sign-in / sign-out ----

  /// Called whenever the signed-in user changes.
  Future<void> attach(String? uid) async {
    if (_registering || uid == _uid) return;
    _resetSession();
    _uid = uid;
    if (uid == null) {
      _setStatus(VaultStatus.signedOut);
      return;
    }
    await _loadAccount(uid);
  }

  /// Retry after [VaultStatus.error].
  Future<void> reload() async {
    final uid = _uid;
    if (uid != null) await _loadAccount(uid);
  }

  Future<void> _loadAccount(String uid) async {
    _setStatus(VaultStatus.loading);
    try {
      final profile = await repository.getProfile(uid);
      final meta = await repository.getVaultMeta(uid);
      if (_uid != uid) return; // signed out / switched meanwhile
      _profile = profile;
      _meta = meta;
      loadError = null;
      _setStatus(meta == null ? VaultStatus.needsSetup : VaultStatus.locked);
    } catch (e) {
      debugPrint('Could not load the account: $e');
      if (_uid != uid) return;
      loadError = "We couldn't load your vault. Check your connection.";
      _setStatus(VaultStatus.error);
    }
  }

  void _resetSession() {
    _subscription?.cancel();
    _subscription = null;
    _key = null;
    _meta = null;
    _profile = null;
    _items = const [];
    _itemsLoaded = false;
    _undecryptable = 0;
    _breachedIds = {};
    _breachCheckedAt = null;
    _breachCheckIncomplete = false;
    _applySequence++;
    loadError = null;
  }

  void _setStatus(VaultStatus status) {
    _status = status;
    notifyListeners();
  }

  // ---- creating and unlocking the vault ----

  /// Creates the account, its profile and its vault in one go.
  ///
  /// If anything fails after the account was created, the account is removed
  /// again so the user can simply retry.
  Future<void> registerAccount({
    required AuthProvider auth,
    required String name,
    required String email,
    required String accountPassword,
    required String masterPassword,
  }) async {
    _registering = true;
    String? uid;
    try {
      uid = await auth.signUp(email: email, password: accountPassword);
      final profile = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        createdAt: _clock(),
      );
      await repository.saveProfile(profile);
      _resetSession();
      _uid = uid;
      _profile = profile;
      await _createVault(uid, masterPassword);
    } catch (e) {
      if (uid != null) await auth.discardCurrentAccount();
      _resetSession();
      _uid = null;
      rethrow;
    } finally {
      _registering = false;
    }
  }

  /// For signed-in accounts that don't have a vault yet.
  Future<void> createVault(String masterPassword) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    await _createVault(uid, masterPassword);
  }

  Future<void> _createVault(String uid, String masterPassword) async {
    final kdf = crypto.newKdfParams();
    final key = await crypto.deriveKey(masterPassword, kdf);
    final meta = VaultMeta(
      salt: kdf.salt,
      iterations: kdf.iterations,
      verifier: await crypto.makeVerifier(key),
      // A brand-new account has nothing to migrate; an account from an older
      // version may have plaintext credentials that still need encrypting.
      legacyMigrated: _profile?.legacyUserId == null,
    );
    await repository.saveVaultMeta(uid, meta);
    _meta = meta;
    await _enterUnlocked(key);
  }

  /// Returns `false` for a wrong master password.
  Future<bool> unlock(String masterPassword) async {
    final meta = _meta;
    if (meta == null) throw StateError('No vault to unlock');
    final key = await crypto.deriveKey(masterPassword, meta.kdf);
    if (!await crypto.checkVerifier(key, meta.verifier)) return false;
    await _enterUnlocked(key);
    return true;
  }

  Future<void> _enterUnlocked(SecretKey key) async {
    _key = key;
    _itemsLoaded = false;
    _items = const [];
    _setStatus(VaultStatus.unlocked);
    final uid = _uid!;

    _subscription?.cancel();
    _subscription = repository
        .watchRecords(uid)
        .listen(
          (records) => unawaited(_applyRecords(records, key)),
          onError: (Object e) {
            debugPrint('Vault stream error: $e');
            loadError = "Lost connection to your vault.";
            notifyListeners();
          },
        );
    unawaited(_migrateLegacy(uid, key));
  }

  /// Wipes everything secret from memory. The vault stays signed in.
  void lock() {
    if (_status != VaultStatus.unlocked) return;
    _subscription?.cancel();
    _subscription = null;
    _key = null;
    _items = const [];
    _itemsLoaded = false;
    _breachedIds = {};
    _applySequence++;
    _setStatus(VaultStatus.locked);
  }

  /// `true` when [masterPassword] is the current one (for sensitive actions).
  Future<bool> verifyMasterPassword(String masterPassword) async {
    final meta = _meta;
    if (meta == null) return false;
    final key = await crypto.deriveKey(masterPassword, meta.kdf);
    return crypto.checkVerifier(key, meta.verifier);
  }

  // ---- reading records ----

  Future<void> _applyRecords(
    List<EncryptedRecord> records,
    SecretKey key,
  ) async {
    final sequence = ++_applySequence;
    final decrypted = <Credential>[];
    var failed = 0;
    for (final r in records) {
      final data = r.data;
      if (data == null) continue; // legacy: handled by the migration
      try {
        decrypted.add(
          Credential.fromPayload(
            r.id,
            await crypto.decrypt(key, data),
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        );
      } catch (_) {
        failed++;
      }
    }
    // Ignore the result if the vault was locked or a newer update arrived.
    if (sequence != _applySequence || !identical(_key, key)) return;
    _items = decrypted;
    _undecryptable = failed;
    _itemsLoaded = true;
    loadError = null;
    notifyListeners();
  }

  /// Encrypts credentials saved by older (plaintext) versions of the app.
  Future<void> _migrateLegacy(String uid, SecretKey key) async {
    final meta = _meta;
    final legacyId = _profile?.legacyUserId;
    if (meta == null || meta.legacyMigrated) return;
    try {
      if (legacyId != null) {
        final legacy = await repository.getLegacyRecords(legacyId);
        for (final r in legacy) {
          final old = r.legacy;
          if (old == null) continue;
          final platform = PlatformCatalog.normalise(
            old['platform'] as String? ?? PlatformCatalog.other,
          );
          final credential = Credential(
            id: r.id,
            platform: platform,
            username: old['username'] as String? ?? '',
            password: old['password'] as String? ?? '',
            url: old['url'] as String? ?? '',
            category: PlatformCatalog.of(platform).category,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            passwordChangedAt: r.updatedAt,
          );
          await repository.putRecord(
            uid,
            r.id,
            await crypto.encrypt(key, credential.toPayload()),
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          );
        }
      }
      final done = meta.copyWith(legacyMigrated: true);
      await repository.saveVaultMeta(uid, done);
      if (identical(_key, key)) _meta = done;
    } catch (e) {
      // Not fatal: it is retried the next time the vault is unlocked.
      debugPrint('Legacy migration skipped: $e');
    }
  }

  // ---- changing credentials ----

  SecretKey get _requireKey {
    final key = _key;
    if (key == null) throw StateError('The vault is locked');
    return key;
  }

  /// Saves a new credential (its [Credential.id] is ignored) and returns it.
  Future<Credential> add(Credential draft) async {
    final key = _requireKey;
    final uid = _uid!;
    final now = _clock();
    final credential = draft.copyWith(
      createdAt: now,
      updatedAt: now,
      passwordChangedAt: now,
    );
    final id = await repository.addRecord(
      uid,
      await crypto.encrypt(key, credential.toPayload()),
      now,
    );
    final saved = credential.copyWith(id: id);
    // Show it immediately; the live stream confirms it right after.
    _items = [saved, ..._items.where((c) => c.id != id)];
    notifyListeners();
    return saved;
  }

  Future<Credential> update(Credential edited) async {
    final key = _requireKey;
    final now = _clock();
    final previous = _items.where((c) => c.id == edited.id).firstOrNull;
    final passwordChanged =
        previous == null || previous.password != edited.password;
    final saved = edited.copyWith(
      updatedAt: now,
      passwordChangedAt: passwordChanged ? now : edited.passwordChangedAt,
    );
    await repository.updateRecord(
      saved.id,
      await crypto.encrypt(key, saved.toPayload()),
      now,
    );
    _items = [for (final c in _items) c.id == saved.id ? saved : c];
    // A changed password invalidates an earlier breach result.
    if (passwordChanged) _breachedIds = {..._breachedIds}..remove(saved.id);
    notifyListeners();
    return saved;
  }

  Future<void> toggleFavorite(Credential c) =>
      update(c.copyWith(favorite: !c.favorite));

  Future<void> delete(Credential c) async {
    _requireKey;
    await repository.deleteRecord(c.id);
    _items = _items.where((x) => x.id != c.id).toList();
    _breachedIds = {..._breachedIds}..remove(c.id);
    notifyListeners();
  }

  /// Puts a deleted credential back exactly as it was (undo).
  Future<void> restore(Credential c) async {
    final key = _requireKey;
    await repository.putRecord(
      _uid!,
      c.id,
      await crypto.encrypt(key, c.toPayload()),
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
    _items = [c, ..._items.where((x) => x.id != c.id)];
    notifyListeners();
  }

  // ---- master password, name, danger zone ----

  /// Re-encrypts everything under a new master password.
  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final meta = _meta;
    final uid = _uid;
    if (meta == null || uid == null) throw StateError('No vault');
    _requireKey;

    final oldKey = await crypto.deriveKey(currentPassword, meta.kdf);
    if (!await crypto.checkVerifier(oldKey, meta.verifier)) {
      throw const WrongMasterPassword();
    }

    final kdf = crypto.newKdfParams();
    final newKey = await crypto.deriveKey(newPassword, kdf);
    final newMeta = VaultMeta(
      salt: kdf.salt,
      iterations: kdf.iterations,
      verifier: await crypto.makeVerifier(newKey),
      legacyMigrated: meta.legacyMigrated,
    );

    final rewritten = <String, String>{
      for (final c in _items) c.id: await crypto.encrypt(newKey, c.toPayload()),
    };
    // Re-encrypt the data first, then publish the new key material.
    await repository.rewriteRecords(rewritten, _clock());
    await repository.saveVaultMeta(uid, newMeta);

    _meta = newMeta;
    _key = newKey;
    _subscription?.cancel();
    _subscription = repository
        .watchRecords(uid)
        .listen((records) => unawaited(_applyRecords(records, newKey)));
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final profile = _profile;
    if (profile == null) return;
    final updated = profile.copyWith(name: name.trim());
    await repository.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  /// Forgot the master password? The only way out is to erase the vault and
  /// start again (nobody, including us, can recover the data).
  Future<void> eraseVault() async {
    final uid = _uid;
    if (uid == null) return;
    await repository.deleteVault(uid);
    _resetSession();
    _meta = null;
    _profile = await repository.getProfile(uid);
    _setStatus(VaultStatus.needsSetup);
  }

  /// Deletes all of the user's data (before the account itself is deleted).
  Future<void> deleteEverything() async {
    final uid = _uid;
    if (uid == null) return;
    await repository.deleteVault(uid, deleteProfile: true);
  }

  // ---- security checks ----

  /// Checks every distinct password against known breaches. Nothing but a
  /// partial hash of each password leaves the device.
  Future<void> checkAllBreaches() async {
    final checker = _breachChecker;
    if (checker == null || _checkingBreaches || !isUnlocked) return;
    _checkingBreaches = true;
    _breachCheckIncomplete = false;
    notifyListeners();

    final found = <String>{};
    final cache = <String, int?>{};
    for (final c in _items) {
      if (c.password.isEmpty) continue;
      final count = cache.containsKey(c.password)
          ? cache[c.password]
          : cache[c.password] = await checker.pwnedCount(c.password);
      if (count == null) {
        _breachCheckIncomplete = true;
      } else if (count > 0) {
        found.add(c.id);
      }
      if (!isUnlocked) break; // locked while checking
    }
    _checkingBreaches = false;
    if (isUnlocked) {
      _breachedIds = found;
      _breachCheckedAt = _clock();
    }
    notifyListeners();
  }

  /// How often one password appears in breaches (`null` = could not check).
  Future<int?> checkPassword(String password) async =>
      _breachChecker?.pwnedCount(password);

  bool _disposed = false;

  /// Decryption and network calls finish asynchronously, so a result can
  /// arrive after the provider is gone (e.g. while the app is closing).
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
