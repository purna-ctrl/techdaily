import 'package:cloud_firestore/cloud_firestore.dart';

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Same rule as `firestore.rules` → `signups`.
bool isValidEmail(String email) {
  final e = email.trim();
  return e.length >= 6 && e.length <= 254 && _emailRe.hasMatch(e);
}

class NewsletterException implements Exception {
  final String message;
  NewsletterException(this.message);
  @override
  String toString() => message;
}

abstract class NewsletterService {
  /// Adds [email] to the "Today in 5" newsletter list. [source] says where the
  /// form was (e.g. `app-settings`, `app-story`).
  Future<void> signUp(String email, {required String source});
}

/// Writes `signups/{auto}` = {email, source, createdAt: request.time}.
/// Firestore rules allow create only (no reads), so the list stays private.
class FirestoreNewsletterService implements NewsletterService {
  final FirebaseFirestore _db;
  FirestoreNewsletterService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  @override
  Future<void> signUp(String email, {required String source}) async {
    final e = email.trim().toLowerCase();
    if (!isValidEmail(e)) throw NewsletterException('Please enter a valid email address.');
    try {
      await _db.collection('signups').add({
        'email': e,
        'source': source.length > 40 ? source.substring(0, 40) : source,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      throw NewsletterException('Could not sign you up right now. Please try again later.');
    }
  }
}

/// Records sign-ups in memory (tests / offline demo).
class LocalNewsletterService implements NewsletterService {
  final List<(String, String)> signups = [];

  @override
  Future<void> signUp(String email, {required String source}) async {
    final e = email.trim().toLowerCase();
    if (!isValidEmail(e)) throw NewsletterException('Please enter a valid email address.');
    signups.add((e, source));
  }
}
