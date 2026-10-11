import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// An authentication error with a message that is safe to show to the user.
class AuthFailure implements Exception {
  final String code;
  final String message;

  const AuthFailure(this.code, this.message);

  factory AuthFailure.fromCode(String code) {
    switch (code) {
      // Newer Firebase versions report every bad sign-in as invalid-credential.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return AuthFailure(code, 'Incorrect email or password.');
      case 'invalid-email':
        return AuthFailure(code, 'That email address does not look right.');
      case 'user-disabled':
        return AuthFailure(code, 'This account has been disabled.');
      case 'email-already-in-use':
        return AuthFailure(code, 'An account with this email already exists.');
      case 'weak-password':
        return AuthFailure(code, 'Please choose a stronger account password.');
      case 'too-many-requests':
        return AuthFailure(code, 'Too many attempts. Please try again later.');
      case 'network-request-failed':
        return AuthFailure(code, 'No internet connection. Please try again.');
      case 'requires-recent-login':
        return AuthFailure(code, 'Please sign in again to do that.');
      default:
        return AuthFailure(code, 'Something went wrong. Please try again.');
    }
  }

  @override
  String toString() => message;
}

/// Account sign-in (not the vault: that is unlocked with the master password).
abstract class AuthProvider extends ChangeNotifier {
  /// `false` until Firebase has reported the initial sign-in state.
  bool get initialized;

  /// Firebase uid of the signed-in user, or `null`.
  String? get userId;
  String? get email;
  bool get isSignedIn => userId != null;

  Future<void> signIn({required String email, required String password});

  /// Creates an account and returns its uid.
  Future<String> signUp({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Confirms the signed-in user's account [password].
  Future<void> reauthenticate(String password);

  /// Permanently deletes the signed-in account (call [reauthenticate] first).
  Future<void> deleteAccount();

  /// Removes an account that was just created, to roll back a failed signup.
  Future<void> discardCurrentAccount();
}

class FirebaseAuthProvider extends AuthProvider {
  FirebaseAuthProvider({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance {
    _subscription = _auth.authStateChanges().listen((_) {
      _initialized = true;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  bool _initialized = false;

  @override
  bool get initialized => _initialized;

  @override
  String? get userId => _auth.currentUser?.uid;

  @override
  String? get email => _auth.currentUser?.email;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code}');
      throw AuthFailure.fromCode(e.code);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<String> signUp({required String email, required String password}) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return credential.user!.uid;
      });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> reauthenticate(String password) => _guard(() async {
    final user = _auth.currentUser;
    final address = user?.email;
    if (user == null || address == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: address, password: password),
    );
  });

  @override
  Future<void> deleteAccount() =>
      _guard(() async => _auth.currentUser?.delete());

  @override
  Future<void> discardCurrentAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('Could not discard account: ${e.code}');
      await _auth.signOut();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
