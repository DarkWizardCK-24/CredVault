import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cred_vault/models/user_model.dart';
import 'package:cred_vault/models/vault_models.dart';

/// Storage contract for the user's profile, vault settings and encrypted
/// credentials. The app only talks to this interface (tests use a fake).
///
/// Nothing here ever sees a master password or an unencrypted credential.
abstract class VaultRepository {
  Future<UserModel?> getProfile(String uid);

  Future<void> saveProfile(UserModel user);

  Future<VaultMeta?> getVaultMeta(String uid);

  Future<void> saveVaultMeta(String uid, VaultMeta meta);

  /// All of the user's records, newest first, live.
  Stream<List<EncryptedRecord>> watchRecords(String uid);

  /// Stores a new encrypted record and returns its id.
  Future<String> addRecord(String uid, String data, DateTime now);

  /// Replaces the data of an existing record.
  Future<void> updateRecord(String id, String data, DateTime now);

  /// Writes a record with a known id (used by undo and by migration).
  Future<void> putRecord(
    String uid,
    String id,
    String data, {
    required DateTime createdAt,
    required DateTime updatedAt,
  });

  Future<void> deleteRecord(String id);

  /// Replaces the data of many records at once (master password change).
  Future<void> rewriteRecords(Map<String, String> dataById, DateTime now);

  /// Records saved by older versions, found through their old user id.
  /// Returns an empty list if they can't be read.
  Future<List<EncryptedRecord>> getLegacyRecords(String legacyUserId);

  /// Deletes every record, the vault settings and (optionally) the profile.
  Future<void> deleteVault(String uid, {bool deleteProfile = false});
}

class FirestoreVaultRepository implements VaultRepository {
  FirestoreVaultRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _creds =>
      _db.collection('credentials');

  /// Firestore completes a write only once the server confirms it, which
  /// never happens offline. The write is queued locally either way, so don't
  /// make the UI wait for the server.
  static const Duration _serverWait = Duration(seconds: 4);

  Future<void> _write(Future<void> write) =>
      write.timeout(_serverWait, onTimeout: () {});

  @override
  Future<UserModel?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  @override
  Future<void> saveProfile(UserModel user) =>
      _write(_users.doc(user.uid).set(user.toMap(), SetOptions(merge: true)));

  @override
  Future<VaultMeta?> getVaultMeta(String uid) async {
    final doc = await _users.doc(uid).get();
    final vault = doc.data()?['vault'];
    return VaultMeta.fromMap(vault is Map<String, dynamic> ? vault : null);
  }

  @override
  Future<void> saveVaultMeta(String uid, VaultMeta meta) => _write(
    _users.doc(uid).set({'vault': meta.toMap()}, SetOptions(merge: true)),
  );

  EncryptedRecord _record(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final created = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updated = (d['updatedAt'] as Timestamp?)?.toDate() ?? created;
    final data = d['data'] as String?;
    return EncryptedRecord(
      id: doc.id,
      data: data,
      // Records from older versions have plaintext fields instead of `data`.
      legacy: data == null ? d : null,
      createdAt: created,
      updatedAt: updated,
    );
  }

  @override
  Stream<List<EncryptedRecord>> watchRecords(String uid) => _creds
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(_record).toList());

  @override
  Future<String> addRecord(String uid, String data, DateTime now) async {
    final ref = _creds.doc();
    await _write(
      ref.set({
        'userId': uid,
        'v': 2,
        'data': data,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }),
    );
    return ref.id;
  }

  @override
  Future<void> updateRecord(String id, String data, DateTime now) => _write(
    _creds.doc(id).update({'data': data, 'updatedAt': Timestamp.fromDate(now)}),
  );

  @override
  Future<void> putRecord(
    String uid,
    String id,
    String data, {
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => _write(
    // No merge: this also removes any plaintext fields of a legacy record.
    _creds.doc(id).set({
      'userId': uid,
      'v': 2,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    }),
  );

  @override
  Future<void> deleteRecord(String id) => _write(_creds.doc(id).delete());

  @override
  Future<void> rewriteRecords(
    Map<String, String> dataById,
    DateTime now,
  ) async {
    final entries = dataById.entries.toList();
    // A batch holds at most 500 writes.
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(400)) {
        batch.update(_creds.doc(e.key), {
          'data': e.value,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<List<EncryptedRecord>> getLegacyRecords(String legacyUserId) async {
    try {
      final snap = await _creds.where('userId', isEqualTo: legacyUserId).get();
      return snap.docs.map(_record).toList();
    } on FirebaseException {
      return const [];
    }
  }

  @override
  Future<void> deleteVault(String uid, {bool deleteProfile = false}) async {
    while (true) {
      final page = await _creds
          .where('userId', isEqualTo: uid)
          .limit(400)
          .get();
      if (page.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    if (deleteProfile) {
      await _users.doc(uid).delete();
    } else {
      await _users.doc(uid).update({'vault': FieldValue.delete()});
    }
  }
}
