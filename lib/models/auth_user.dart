import 'package:cloud_firestore/cloud_firestore.dart';

class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AuthUser.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawCreated = map['createdAt'];
    DateTime parsedCreated;
    if (rawCreated is Timestamp) {
      parsedCreated = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    return AuthUser(
      uid: map['uid'] as String? ?? (docId ?? ''),
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      createdAt: parsedCreated,
    );
  }

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
