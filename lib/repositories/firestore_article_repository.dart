import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import 'article_repository.dart';
import 'guest_bookmark_store.dart';

class FirestoreArticleRepository implements ArticleRepository {
  final FirebaseFirestore _firestore;
  final ValueNotifier<Set<String>> _savedIdsNotifier = ValueNotifier<Set<String>>({});
  StreamSubscription? _savedArticlesSub;
  String? _currentUserId;
  bool _bound = false;
  final GuestBookmarkStore _guestStore;

  FirestoreArticleRepository({
    FirebaseFirestore? firestore,
    GuestBookmarkStore? guestStore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _guestStore = guestStore ?? const GuestBookmarkStore() {
    // Guests see their device-local saves straight away.
    _guestStore.load().then((ids) {
      if ((_currentUserId ?? '').isEmpty && ids.isNotEmpty) {
        _savedIdsNotifier.value = {..._savedIdsNotifier.value, ...ids};
      }
    });
  }

  bool get _isGuest => (_currentUserId ?? '').isEmpty;

  CollectionReference<Map<String, dynamic>> get _articlesCol =>
      _firestore.collection('articles');

  CollectionReference<Map<String, dynamic>> _userSavedCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('savedArticles');

  /// Binds bookmarks to the signed-in user (or the guest store when null).
  /// On sign-in, bookmarks saved as a guest are merged into Firestore.
  Future<void> bindUserBookmarks(String? userId) async {
    if (_bound && _currentUserId == userId) return;
    _bound = true;
    _currentUserId = userId;
    await _savedArticlesSub?.cancel();
    _savedArticlesSub = null;

    if (userId == null || userId.isEmpty) {
      _savedIdsNotifier.value = await _guestStore.load();
      return;
    }

    await mergeGuestBookmarks(userId);

    _savedArticlesSub = _userSavedCol(userId).snapshots().listen((snapshot) {
      final ids = snapshot.docs.map((doc) => doc.id).toSet();
      _savedIdsNotifier.value = ids;
    }, onError: (_) {
      // Keep existing memory state on snapshot permission error
    });
  }

  /// Copies device-local guest saves into `users/{uid}/savedArticles` and
  /// clears the local list once written. Returns how many were merged.
  Future<int> mergeGuestBookmarks(String userId) async {
    final guestIds = await _guestStore.load();
    if (guestIds.isEmpty) return 0;
    try {
      final batch = _firestore.batch();
      for (final id in guestIds) {
        batch.set(_userSavedCol(userId).doc(id), {
          'articleId': id,
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await _guestStore.clear();
      _savedIdsNotifier.value = {..._savedIdsNotifier.value, ...guestIds};
      return guestIds.length;
    } catch (e) {
      debugPrint('Guest bookmark merge failed (kept locally): $e');
      return 0;
    }
  }

  @override
  ValueListenable<Set<String>> get savedArticleIdsNotifier => _savedIdsNotifier;

  @override
  bool isArticleSaved(String articleId) {
    return _savedIdsNotifier.value.contains(articleId);
  }

  @override
  Future<bool> isArticleSavedForUser(String userId, String articleId) async {
    if (userId.isEmpty) return false;
    try {
      final doc = await _userSavedCol(userId).doc(articleId).get();
      return doc.exists;
    } catch (_) {
      return _savedIdsNotifier.value.contains(articleId);
    }
  }

  @override
  Future<void> saveArticle(String userId, String articleId) async {
    if (userId.isEmpty) {
      final ids = {..._savedIdsNotifier.value, articleId};
      _savedIdsNotifier.value = ids;
      if (_isGuest) await _guestStore.save(ids);
      return;
    }
    await _userSavedCol(userId).doc(articleId).set({
      'articleId': articleId,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _savedIdsNotifier.value = {..._savedIdsNotifier.value, articleId};
  }

  @override
  Future<void> removeSavedArticle(String userId, String articleId) async {
    if (userId.isEmpty) {
      final ids = Set<String>.from(_savedIdsNotifier.value)..remove(articleId);
      _savedIdsNotifier.value = ids;
      if (_isGuest) await _guestStore.save(ids);
      return;
    }
    await _userSavedCol(userId).doc(articleId).delete();
    final updated = Set<String>.from(_savedIdsNotifier.value)..remove(articleId);
    _savedIdsNotifier.value = updated;
  }

  @override
  Future<bool> toggleSaveArticle(String userId, String articleId) async {
    if (userId.isEmpty) {
      final saved = _savedIdsNotifier.value.contains(articleId);
      if (saved) {
        await removeSavedArticle('', articleId);
      } else {
        await saveArticle('', articleId);
      }
      return !saved;
    }
    final isSaved = await isArticleSavedForUser(userId, articleId);
    if (isSaved) {
      await removeSavedArticle(userId, articleId);
      return false;
    } else {
      await saveArticle(userId, articleId);
      return true;
    }
  }

  @override
  Stream<List<Article>> watchArticles({String? category, bool? isBreaking}) {
    Query<Map<String, dynamic>> query = _articlesCol;

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (isBreaking != null) {
      query = query.where('isBreaking', isEqualTo: isBreaking);
    }

    query = query.orderBy('publishedAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  @override
  Stream<List<Article>> watchBreakingNews() {
    return _articlesCol
        .where('isBreaking', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  @override
  Stream<List<Article>> watchArticlesByCategory(String category) {
    return _articlesCol
        .where('category', isEqualTo: category)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
            .toList());
  }

  @override
  Stream<List<Article>> watchSavedArticles(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return _userSavedCol(userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <Article>[];

      final articleIds = snapshot.docs.map((d) => d.id).toList();
      final articles = <Article>[];

      // Fetch corresponding article documents in chunks (max 10 for Firestore 'whereIn')
      for (var i = 0; i < articleIds.length; i += 10) {
        final chunk = articleIds.sublist(
            i, i + 10 > articleIds.length ? articleIds.length : i + 10);
        final chunkQuery = await _articlesCol
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        articles.addAll(chunkQuery.docs
            .map((doc) => Article.fromMap(doc.data(), docId: doc.id)));
      }

      // Preserve saved order
      final articleMap = {for (final a in articles) a.id: a};
      return articleIds
          .where((id) => articleMap.containsKey(id))
          .map((id) => articleMap[id]!)
          .toList();
    });
  }

  @override
  Future<List<Article>> getArticles({String? category, bool? isBreaking}) async {
    Query<Map<String, dynamic>> query = _articlesCol;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (isBreaking != null) {
      query = query.where('isBreaking', isEqualTo: isBreaking);
    }
    query = query.orderBy('publishedAt', descending: true);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Future<List<Article>> getTopStories({int limit = 5}) async {
    final snapshot = await _articlesCol
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Future<List<Article>> getBreakingNews() async {
    final snapshot = await _articlesCol
        .where('isBreaking', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Future<List<Article>> getArticlesByCategory(String category) async {
    final snapshot = await _articlesCol
        .where('category', isEqualTo: category)
        .orderBy('publishedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Future<Article?> getArticleById(String id) async {
    final doc = await _articlesCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Article.fromMap(doc.data()!, docId: doc.id);
  }

  /// Repository-level search abstraction.
  /// Fetches bounded recent candidate articles and filters across title, summary,
  /// category, and source name without unbounded collection scans.
  /// Designed so dedicated search engines (Algolia/Typesense) can be slotted in Phase 3.
  @override
  Future<List<Article>> searchArticles(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    // Query candidates (bounded to recent 100 articles to avoid full DB scan)
    final snapshot = await _articlesCol
        .orderBy('publishedAt', descending: true)
        .limit(100)
        .get();

    final candidates = snapshot.docs
        .map((doc) => Article.fromMap(doc.data(), docId: doc.id))
        .toList();

    return candidates.where((article) {
      final titleMatch = article.title.toLowerCase().contains(cleanQuery);
      final summaryMatch = article.summary.toLowerCase().contains(cleanQuery);
      final categoryMatch = article.category.toLowerCase().contains(cleanQuery);
      final sourceMatch = article.sourceName.toLowerCase().contains(cleanQuery);
      final whatHappenedMatch =
          article.whatHappened.toLowerCase().contains(cleanQuery);
      final whyItMattersMatch =
          article.whyItMatters.toLowerCase().contains(cleanQuery);
      final explanationMatch =
          article.simpleExplanation.toLowerCase().contains(cleanQuery);

      return titleMatch ||
          summaryMatch ||
          categoryMatch ||
          sourceMatch ||
          whatHappenedMatch ||
          whyItMattersMatch ||
          explanationMatch;
    }).toList();
  }

  @override
  Future<List<Article>> getArticlesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final articles = <Article>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final q = await _articlesCol.where(FieldPath.documentId, whereIn: chunk).get();
      articles.addAll(q.docs.map((d) => Article.fromMap(d.data(), docId: d.id)));
    }
    final map = {for (final a in articles) a.id: a};
    return [for (final id in ids) if (map[id] != null) map[id]!];
  }

  @override
  Future<List<Article>> getSavedArticles(String userId) async {
    if (userId.isEmpty) return [];
    final snapshot = await _userSavedCol(userId)
        .orderBy('savedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final articleIds = snapshot.docs.map((d) => d.id).toList();
    final articles = <Article>[];

    for (var i = 0; i < articleIds.length; i += 10) {
      final chunk = articleIds.sublist(
          i, i + 10 > articleIds.length ? articleIds.length : i + 10);
      final chunkQuery = await _articlesCol
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      articles.addAll(chunkQuery.docs
          .map((doc) => Article.fromMap(doc.data(), docId: doc.id)));
    }

    final articleMap = {for (final a in articles) a.id: a};
    return articleIds
        .where((id) => articleMap.containsKey(id))
        .map((id) => articleMap[id]!)
        .toList();
  }
}
