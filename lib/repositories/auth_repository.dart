import 'dart:async';
import '../models/auth_user.dart';

/// Abstract contract for Authentication operations.
/// Completely decouples UI widgets from FirebaseAuth or other auth providers.
abstract class AuthRepository {
  /// Stream of authentication state changes.
  Stream<AuthUser?> get authStateChanges;

  /// Returns current authenticated user, or null if unauthenticated.
  AuthUser? get currentUser;

  /// Signs in a user with email and password.
  Future<AuthUser> signIn(String email, String password);

  /// Registers a new user with email, password, and optional display name.
  Future<AuthUser> signUp(String email, String password, {String? displayName});

  /// Signs in with Google (popup on web, native provider flow on Android).
  Future<AuthUser> signInWithGoogle();

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email);

  /// Permanently deletes the signed-in account and its saved data.
  Future<void> deleteAccount();
}

/// In-memory implementation of [AuthRepository] used for testing and offline fallback.
class LocalAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _authController =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  LocalAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  @override
  Stream<AuthUser?> get authStateChanges => _authController.stream;

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be blank.');
    }
    final user = AuthUser(
      uid: 'local-user-id-${email.hashCode}',
      email: email.trim(),
      displayName: email.split('@').first,
      createdAt: DateTime.now(),
    );
    _user = user;
    _authController.add(_user);
    return user;
  }

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final user = AuthUser(
      uid: 'local-user-id-${email.hashCode}',
      email: email.trim(),
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : email.split('@').first,
      createdAt: DateTime.now(),
    );
    _user = user;
    _authController.add(_user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    throw Exception('Google sign-in needs an internet connection.');
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _authController.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      throw Exception('Please provide a valid email address.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    _user = null;
    _authController.add(null);
  }

  void dispose() {
    _authController.close();
  }
}
