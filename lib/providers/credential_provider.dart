import 'package:cred_vault/models/credential_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CredentialProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CredentialModel> _credentials = [];
  bool _isLoading = false;

  List<CredentialModel> get credentials => _credentials;
  bool get isLoading => _isLoading;

  Future<void> loadCredentials(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      QuerySnapshot snapshot = await _firestore
          .collection('credentials')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _credentials = snapshot.docs
          .map((doc) => CredentialModel.fromFirestore(doc))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading credentials: $e');
    }
  }

  Future<String?> addCredential({
    required String userId,
    required String platform,
    required String username,
    required String password,
    required String url,
  }) async {
    try {
      // Generate unique credential ID
      int credCount = await _getCredentialCount();
      String credId = 'CRED${(credCount + 1).toString().padLeft(6, '0')}';

      CredentialModel credential = CredentialModel(
        credId: credId,
        userId: userId,
        platform: platform,
        username: username,
        password: password,
        url: url,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('credentials')
          .doc(credId)
          .set(credential.toMap());

      _credentials.insert(0, credential);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to add credential: $e';
    }
  }

  Future<String?> updateCredential({
    required String credId,
    required String platform,
    required String username,
    required String password,
    required String url,
  }) async {
    try {
      await _firestore.collection('credentials').doc(credId).update({
        'platform': platform,
        'username': username,
        'password': password,
        'url': url,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      int index = _credentials.indexWhere((c) => c.credId == credId);
      if (index != -1) {
        _credentials[index] = _credentials[index].copyWith(
          platform: platform,
          username: username,
          password: password,
          url: url,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return null;
    } catch (e) {
      return 'Failed to update credential: $e';
    }
  }

  Future<String?> deleteCredential(String credId) async {
    try {
      await _firestore.collection('credentials').doc(credId).delete();
      _credentials.removeWhere((c) => c.credId == credId);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete credential: $e';
    }
  }

  Future<int> _getCredentialCount() async {
    QuerySnapshot snapshot = await _firestore.collection('credentials').get();
    return snapshot.docs.length;
  }

  List<CredentialModel> searchCredentials(String query) {
    if (query.isEmpty) return _credentials;

    String lowerQuery = query.toLowerCase();
    return _credentials.where((cred) {
      return cred.platform.toLowerCase().contains(lowerQuery) ||
          cred.username.toLowerCase().contains(lowerQuery) ||
          cred.credId.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
