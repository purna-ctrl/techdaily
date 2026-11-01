import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';

class FirebaseAuthService implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  AuthUser? _mapFirebaseUser(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  @override
  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw Exception('Sign in succeeded but returned empty user credential.');
      }
      return _mapFirebaseUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _humanizeAuthError(e);
    } catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final cleanEmail = email.trim();
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw Exception('User registration returned empty credential.');
      }

      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }

      // Create users/{userId} document in Firestore
      final now = DateTime.now();
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': cleanEmail,
        'displayName': displayName?.trim() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return AuthUser(
        uid: user.uid,
        email: cleanEmail,
        displayName: displayName?.trim(),
        createdAt: now,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _humanizeAuthError(e);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final provider = fb.GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      final credential = kIsWeb
          ? await _firebaseAuth.signInWithPopup(provider)
          : await _firebaseAuth.signInWithProvider(provider);
      final user = credential.user;
      if (user == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'lastSignInAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Profile doc is best-effort; sign-in itself succeeded.
      }
      return _mapFirebaseUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _humanizeAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _humanizeAuthError(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  String _humanizeAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email address or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return 'Google sign-in was cancelled.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in pop-up. Allow pop-ups and try again.';
      case 'operation-not-allowed':
        return 'Google sign-in isn’t enabled yet. Please use email for now.';
      case 'unauthorized-domain':
        return 'This website isn’t authorised for Google sign-in yet.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Sign in with email and password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few moments and try again.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }
}
