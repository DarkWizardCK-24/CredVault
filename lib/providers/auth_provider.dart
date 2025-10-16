import 'package:cred_vault/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate unique user ID
      int userCount = await _getUserCount();
      String userId = 'USER${(userCount + 1).toString().padLeft(6, '0')}';

      // Create user document
      UserModel newUser = UserModel(
        userId: userId,
        name: name,
        email: email,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(newUser.toMap());

      _userModel = newUser;
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Registration failed';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An error occurred: $e';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Login failed';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An error occurred: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  Future<String?> updateProfile({
    required String name,
  }) async {
    try {
      if (_user == null) return 'User not authenticated';

      await _firestore.collection('users').doc(_user!.uid).update({
        'name': name,
      });

      _userModel = _userModel?.copyWith(name: name);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update profile: $e';
    }
  }

  Future<int> _getUserCount() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    return snapshot.docs.length;
  }
}