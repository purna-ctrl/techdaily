import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/article.dart';
import '../services/local_article_service.dart';

/// Abstract Article Repository defining contracts for data operations.
/// Completely separates presentation widgets from Firestore or local data sources.
abstract class ArticleRepository {
  /// Stream of all articles, optionally filtered.
  Stream<List<Article>> watchArticles({String? category, bool? isBreaking});

  /// Stream of breaking news articles.
  Stream<List<Article>> watchBreakingNews();

  /// Stream of articles belonging to a specific category.
  Stream<List<Article>> watchArticlesByCategory(String category);

  /// Stream of saved articles for an authenticated user.
  Stream<List<Article>> watchSavedArticles(String userId);

  /// Retrieves all articles, optionally filtered by category or breaking status.
  Future<List<Article>> getArticles({String? category, bool? isBreaking});

  /// Retrieves top stories (featured leading articles).
  Future<List<Article>> getTopStories({int limit = 5});

  /// Retrieves articles tagged as breaking news.
  Future<List<Article>> getBreakingNews();

  /// Retrieves articles belonging to a specific category.
  Future<List<Article>> getArticlesByCategory(String category);

  /// Retrieves a single article by ID.
  Future<Article?> getArticleById(String id);

  /// Search abstraction across articles.
  Future<List<Article>> searchArticles(String query);

  /// Retrieves the given articles (missing ids are skipped), keeping order.
  Future<List<Article>> getArticlesByIds(List<String> ids);

  /// Retrieves all articles saved/bookmarked by the user.
  Future<List<Article>> getSavedArticles(String userId);

  /// Toggles saved state for an article ID for a given user.
  Future<bool> toggleSaveArticle(String userId, String articleId);

  /// Explicitly saves an article for a user.
  Future<void> saveArticle(String userId, String articleId);

  /// Explicitly removes a saved article for a user.
  Future<void> removeSavedArticle(String userId, String articleId);

  /// Checks if an article is currently saved for a user.
  Future<bool> isArticleSavedForUser(String userId, String articleId);

  /// Checks if an article is currently saved locally.
  bool isArticleSaved(String articleId);

  /// Reactive notifier for saved article IDs (useful for immediate UI updates).
  ValueListenable<Set<String>> get savedArticleIdsNotifier;
}

/// Concrete implementation of [ArticleRepository] backed by [LocalArticleService].
/// Acts as offline fallback and supports Phase 1 tests.
class LocalArticleRepository implements ArticleRepository {
  final LocalArticleService _articleService;
  final ValueNotifier<Set<String>> _savedIdsNotifier = ValueNotifier<Set<String>>({});
  late final Future<void> _initFuture;

  LocalArticleRepository({LocalArticleService? articleService})
      : _articleService = articleService ?? LocalArticleService() {
    _initFuture = _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(AppConstants.savedArticleIdsKey) ?? [];
      _savedIdsNotifier.value = {..._savedIdsNotifier.value, ...savedList};
    } catch (_) {
      // Memory state fallback
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
    await _initFuture;
    return _savedIdsNotifier.value.contains(articleId);
  }

  @override
  Future<bool> toggleSaveArticle(String userId, String articleId) async {
    await _initFuture;
    final current = Set<String>.from(_savedIdsNotifier.value);
    final isSavedNow = !current.contains(articleId);

    if (isSavedNow) {
      current.add(articleId);
    } else {
      current.remove(articleId);
    }

    _savedIdsNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.savedArticleIdsKey, current.toList());
    } catch (_) {}

    return isSavedNow;
  }

  @override
  Future<void> saveArticle(String userId, String articleId) async {
    await _initFuture;
    final current = Set<String>.from(_savedIdsNotifier.value)..add(articleId);
    _savedIdsNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.savedArticleIdsKey, current.toList());
    } catch (_) {}
  }

  @override
  Future<void> removeSavedArticle(String userId, String articleId) async {
    await _initFuture;
    final current = Set<String>.from(_savedIdsNotifier.value)..remove(articleId);
    _savedIdsNotifier.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.savedArticleIdsKey, current.toList());
    } catch (_) {}
  }

  @override
  Stream<List<Article>> watchArticles({String? category, bool? isBreaking}) async* {
    final list = await getArticles(category: category, isBreaking: isBreaking);
    yield list;
  }

  @override
  Stream<List<Article>> watchBreakingNews() async* {
    final list = await getBreakingNews();
    yield list;
  }

  @override
  Stream<List<Article>> watchArticlesByCategory(String category) async* {
    final list = await getArticlesByCategory(category);
    yield list;
  }

  @override
  Stream<List<Article>> watchSavedArticles(String userId) async* {
    yield await getSavedArticles(userId);
  }

  @override
  Future<List<Article>> getArticles({String? category, bool? isBreaking}) async {
    final all = await _articleService.getSampleArticles();
    return all.where((article) {
      if (category != null && category.isNotEmpty) {
        if (article.category.toLowerCase() != category.toLowerCase()) {
          return false;
        }
      }
      if (isBreaking != null && article.isBreaking != isBreaking) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<Article>> getTopStories({int limit = 5}) async {
    final all = await _articleService.getSampleArticles();
    final sorted = List<Article>.from(all)
      ..sort((a, b) {
        if (a.isBreaking && !b.isBreaking) return -1;
        if (!a.isBreaking && b.isBreaking) return 1;
        return b.publishedAt.compareTo(a.publishedAt);
      });
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Article>> getBreakingNews() async {
    final all = await _articleService.getSampleArticles();
    return all.where((a) => a.isBreaking).toList();
  }

  @override
  Future<List<Article>> getArticlesByCategory(String category) async {
    final all = await _articleService.getSampleArticles();
    return all
        .where((a) => a.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  @override
  Future<Article?> getArticleById(String id) async {
    final all = await _articleService.getSampleArticles();
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Article>> searchArticles(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final all = await _articleService.getSampleArticles();
    return all.where((article) {
      final titleMatch = article.title.toLowerCase().contains(cleanQuery);
      final summaryMatch = article.summary.toLowerCase().contains(cleanQuery);
      final categoryMatch = article.category.toLowerCase().contains(cleanQuery);
      final sourceMatch = article.sourceName.toLowerCase().contains(cleanQuery);
      final whatHappenedMatch = article.whatHappened.toLowerCase().contains(cleanQuery);
      final whyItMattersMatch = article.whyItMatters.toLowerCase().contains(cleanQuery);
      final explanationMatch = article.simpleExplanation.toLowerCase().contains(cleanQuery);

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
    final all = await _articleService.getSampleArticles();
    final map = {for (final a in all) a.id: a};
    return [for (final id in ids) if (map[id] != null) map[id]!];
  }

  @override
  Future<List<Article>> getSavedArticles([String? userId]) async {
    await _initFuture;
    final savedIds = _savedIdsNotifier.value;
    if (savedIds.isEmpty) return [];

    final all = await _articleService.getSampleArticles();
    return all.where((a) => savedIds.contains(a.id)).toList();
  }
}
