import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techdaily/models/auth_user.dart';
import 'package:techdaily/repositories/auth_repository.dart';

void main() {
  group('AuthUser Model Tests', () {
    test('toMap and fromMap work correctly with Timestamp', () {
      final now = DateTime.now();
      final user = AuthUser(
        uid: 'user-001',
        email: 'ada@lovelace.org',
        displayName: 'Ada Lovelace',
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user-001');
      expect(map['email'], 'ada@lovelace.org');
      expect(map['displayName'], 'Ada Lovelace');
      expect(map['createdAt'], isA<Timestamp>());

      final restored = AuthUser.fromMap(map);
      expect(restored.uid, 'user-001');
      expect(restored.email, 'ada@lovelace.org');
      expect(restored.displayName, 'Ada Lovelace');
    });

    test('copyWith works', () {
      final user = AuthUser(
        uid: 'user-002',
        email: 'turing@bletchley.org',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = user.copyWith(displayName: 'Alan Turing');
      expect(updated.displayName, 'Alan Turing');
      expect(updated.uid, 'user-002');
    });
  });

  group('AuthRepository (Local/Fallback) Tests', () {
    late LocalAuthRepository authRepo;

    setUp(() {
      authRepo = LocalAuthRepository();
    });

    tearDown(() {
      authRepo.dispose();
    });

    test('starts unauthenticated', () {
      expect(authRepo.currentUser, isNull);
    });

    test('signUp creates user and emits to stream', () async {
      final streamFuture = authRepo.authStateChanges.first;
      final user = await authRepo.signUp(
        'developer@techdaily.com',
        'password123',
        displayName: 'Tech Developer',
      );

      expect(user.email, 'developer@techdaily.com');
      expect(user.displayName, 'Tech Developer');
      expect(authRepo.currentUser, isNotNull);

      final emittedUser = await streamFuture;
      expect(emittedUser?.email, 'developer@techdaily.com');
    });

    test('signOut clears currentUser and emits null', () async {
      await authRepo.signUp('reader@techdaily.com', 'password123');
      expect(authRepo.currentUser, isNotNull);

      final streamFuture = authRepo.authStateChanges.first;
      await authRepo.signOut();

      expect(authRepo.currentUser, isNull);
      final emitted = await streamFuture;
      expect(emitted, isNull);
    });

    test('signIn authenticates valid user', () async {
      final user = await authRepo.signIn('subscriber@news.com', 'mypassword');
      expect(user.email, 'subscriber@news.com');
      expect(authRepo.currentUser?.email, 'subscriber@news.com');
    });
  });
}
