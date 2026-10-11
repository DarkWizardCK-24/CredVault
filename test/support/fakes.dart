import 'dart:async';

import 'package:cred_vault/app.dart';
import 'package:cred_vault/core/crypto/vault_crypto.dart';
import 'package:cred_vault/core/password/breach_checker.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:cred_vault/models/user_model.dart';
import 'package:cred_vault/models/vault_models.dart';
import 'package:cred_vault/providers/auth_provider.dart';
import 'package:cred_vault/providers/vault_provider.dart';
import 'package:cred_vault/services/settings_service.dart';
import 'package:cred_vault/services/vault_repository.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';

/// A small work factor and no isolate, so tests derive keys instantly.
const VaultCrypto fastCrypto = VaultCrypto(iterations: 1000, useIsolate: false);

/// In-memory [VaultRepository].
class FakeVaultRepository implements VaultRepository {
  final Map<String, UserModel> profiles = {};
  final Map<String, VaultMeta> metas = {};

  /// id -> record, plus who owns it.
  final Map<String, EncryptedRecord> records = {};
  final Map<String, String> owners = {};

  /// Records written by older versions, found through their old user id.
  final Map<String, List<EncryptedRecord>> legacy = {};

  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  /// When set, [saveProfile] throws it.
  Object? saveProfileError;

  /// When set, [getProfile] throws it (simulates being offline).
  Object? loadError;

  @override
  Future<UserModel?> getProfile(String uid) async {
    if (loadError != null) throw loadError!;
    return profiles[uid];
  }

  @override
  Future<void> saveProfile(UserModel user) async {
    if (saveProfileError != null) throw saveProfileError!;
    profiles[user.uid] = user;
  }

  @override
  Future<VaultMeta?> getVaultMeta(String uid) async => metas[uid];

  @override
  Future<void> saveVaultMeta(String uid, VaultMeta meta) async =>
      metas[uid] = meta;

  List<EncryptedRecord> _recordsOf(String uid) {
    final mine = records.values.where((r) => owners[r.id] == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  @override
  Stream<List<EncryptedRecord>> watchRecords(String uid) async* {
    yield _recordsOf(uid);
    await for (final _ in _changes.stream) {
      yield _recordsOf(uid);
    }
  }

  @override
  Future<String> addRecord(String uid, String data, DateTime now) async {
    final id = 'rec-${_nextId++}';
    records[id] = EncryptedRecord(
      id: id,
      data: data,
      createdAt: now,
      updatedAt: now,
    );
    owners[id] = uid;
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updateRecord(String id, String data, DateTime now) async {
    final old = records[id]!;
    records[id] = EncryptedRecord(
      id: id,
      data: data,
      createdAt: old.createdAt,
      updatedAt: now,
    );
    _changes.add(null);
  }

  @override
  Future<void> putRecord(
    String uid,
    String id,
    String data, {
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    records[id] = EncryptedRecord(
      id: id,
      data: data,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    owners[id] = uid;
    _changes.add(null);
  }

  @override
  Future<void> deleteRecord(String id) async {
    records.remove(id);
    owners.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> rewriteRecords(
    Map<String, String> dataById,
    DateTime now,
  ) async {
    dataById.forEach((id, data) {
      final old = records[id]!;
      records[id] = EncryptedRecord(
        id: id,
        data: data,
        createdAt: old.createdAt,
        updatedAt: now,
      );
    });
    _changes.add(null);
  }

  @override
  Future<List<EncryptedRecord>> getLegacyRecords(String legacyUserId) async =>
      legacy[legacyUserId] ?? const [];

  @override
  Future<void> deleteVault(String uid, {bool deleteProfile = false}) async {
    final mine = records.keys.where((id) => owners[id] == uid).toList();
    for (final id in mine) {
      records.remove(id);
      owners.remove(id);
    }
    metas.remove(uid);
    if (deleteProfile) profiles.remove(uid);
    _changes.add(null);
  }
}

/// In-memory [AuthProvider] with a tiny account database.
class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({
    String? signedInUid,
    String? email,
    bool initialized = true,
  }) : _userId = signedInUid,
       _email = email,
       _initialized = initialized;

  /// email -> password
  final Map<String, String> accounts = {};
  String? _userId;
  String? _email;
  final bool _initialized;
  int _counter = 1;

  final List<String> resetEmails = [];
  bool accountDeleted = false;

  @override
  bool get initialized => _initialized;

  @override
  String? get userId => _userId;

  @override
  String? get email => _email;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final stored = accounts[email.trim()];
    if (stored == null || stored != password) {
      throw AuthFailure.fromCode('invalid-credential');
    }
    _userId = 'uid-${email.trim()}';
    _email = email.trim();
    notifyListeners();
  }

  @override
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    if (accounts.containsKey(email.trim())) {
      throw AuthFailure.fromCode('email-already-in-use');
    }
    accounts[email.trim()] = password;
    _userId = 'new-user-${_counter++}';
    _email = email.trim();
    notifyListeners();
    return _userId!;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _email = null;
    notifyListeners();
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<void> reauthenticate(String password) async {
    if (accounts[_email] != password) {
      throw AuthFailure.fromCode('invalid-credential');
    }
  }

  @override
  Future<void> deleteAccount() async {
    accounts.remove(_email);
    accountDeleted = true;
    _userId = null;
    _email = null;
    notifyListeners();
  }

  @override
  Future<void> discardCurrentAccount() async {
    accounts.remove(_email);
    _userId = null;
    _email = null;
    notifyListeners();
  }
}

/// Answers breach checks from a fixed table.
class FakeBreachChecker implements BreachChecker {
  FakeBreachChecker([this.pwned = const {}]);

  /// password -> how many breaches it appears in.
  final Map<String, int> pwned;
  bool offline = false;
  final List<String> asked = [];

  @override
  Future<int?> pwnedCount(String password) async {
    asked.add(password);
    if (offline) return null;
    return pwned[password] ?? 0;
  }
}

Credential sampleCredential({
  String id = '',
  String platform = 'GitHub',
  String title = '',
  String username = 'aarav@example.com',
  String password = 'Tr0ub4dor&3-horse-battery',
  String url = '',
  String notes = '',
  CredentialCategory category = CredentialCategory.development,
  bool favorite = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? passwordChangedAt,
}) {
  final now = DateTime(2026, 10, 13, 15, 40);
  return Credential(
    id: id,
    platform: platform,
    title: title,
    username: username,
    password: password,
    url: url,
    notes: notes,
    category: category,
    favorite: favorite,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    passwordChangedAt: passwordChangedAt ?? now,
  );
}

/// Writes a ready-made vault (profile, vault settings, encrypted records)
/// straight into [repo], the way the app would have left it.
Future<void> seedVault(
  FakeVaultRepository repo, {
  required String uid,
  required String master,
  String name = 'Aarav Mehta',
  String email = 'aarav@example.com',
  List<Credential> items = const [],
  DateTime? createdAt,
}) async {
  repo.profiles[uid] = UserModel(
    uid: uid,
    name: name,
    email: email,
    createdAt: createdAt ?? DateTime(2026, 3, 2),
  );
  final kdf = fastCrypto.newKdfParams();
  final key = await fastCrypto.deriveKey(master, kdf);
  repo.metas[uid] = VaultMeta(
    salt: kdf.salt,
    iterations: kdf.iterations,
    verifier: await fastCrypto.makeVerifier(key),
    legacyMigrated: true,
  );
  var n = 0;
  for (final c in items) {
    final id = c.id.isEmpty ? 'seed-${n++}' : c.id;
    repo.records[id] = EncryptedRecord(
      id: id,
      data: await fastCrypto.encrypt(key, c.copyWith(id: id).toPayload()),
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
    repo.owners[id] = uid;
  }
}

/// A [VaultProvider] wired to fakes.
VaultProvider newVault(
  FakeVaultRepository repo, {
  BreachChecker? breach,
  DateTime Function()? clock,
}) => VaultProvider(
  repository: repo,
  crypto: fastCrypto,
  breachChecker: breach,
  clock: clock ?? () => DateTime(2026, 10, 13, 15, 40),
);

/// The whole app, with fakes, starting at the normal gate (or at [home]).
Widget testApp({
  required FakeAuthProvider auth,
  required VaultProvider vault,
  SettingsService? settings,
  Widget? home,
}) => CredVaultApp(
  auth: auth,
  vault: vault,
  settings: settings ?? SettingsService(),
  home: home,
);

/// Reads a record's raw secret key bytes (for assertions about the key).
Future<List<int>> keyBytes(SecretKey key) => key.extractBytes();

UserModel sampleProfile(String uid, {String name = 'Aarav Mehta'}) => UserModel(
  uid: uid,
  name: name,
  email: 'aarav@example.com',
  createdAt: DateTime(2026, 3, 2),
);
