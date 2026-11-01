import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/daily_brief.dart';
import '../models/user_preferences.dart';

class OfflineCacheService {
  static const String _articlesKey = 'techdaily_cached_articles_v5';
  static const String _dailyBriefKey = 'techdaily_cached_daily_brief_v5';
  static const String _preferencesKey = 'techdaily_user_preferences_v5';
  static const String _lastSyncKey = 'techdaily_last_cache_sync_v5';

  final SharedPreferences? prefs;

  OfflineCacheService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  /// Cache articles to local storage
  Future<void> cacheArticles(List<Article> articles) async {
    try {
      final prefs = await _getPrefs();
      final maps = articles.map((a) {
        final m = a.toMap();
        // Convert Timestamp to ISO strings for JSON compatibility
        m['publishedAt'] = a.publishedAt.toIso8601String();
        m['createdAt'] = a.createdAt.toIso8601String();
        m['updatedAt'] = a.updatedAt.toIso8601String();
        if (a.aiProcessedAt != null) {
          m['aiProcessedAt'] = a.aiProcessedAt!.toIso8601String();
        }
        return m;
      }).toList();

      final jsonStr = jsonEncode(maps);
      await prefs.setString(_articlesKey, jsonStr);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieve cached articles
  Future<List<Article>> getCachedArticles() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_articlesKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((m) => Article.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cache daily brief
  Future<void> cacheDailyBrief(DailyBrief brief) async {
    try {
      final prefs = await _getPrefs();
      final map = brief.toMap();
      map['date'] = brief.date.toIso8601String();
      map['createdAt'] = brief.createdAt.toIso8601String();
      await prefs.setString(_dailyBriefKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Retrieve cached daily brief
  Future<DailyBrief?> getCachedDailyBrief() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_dailyBriefKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DailyBrief.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Cache user preferences
  Future<void> cachePreferences(UserPreferences prefsData) async {
    try {
      final prefs = await _getPrefs();
      final map = prefsData.toMap();
      map['updatedAt'] = prefsData.updatedAt.toIso8601String();
      await prefs.setString(_preferencesKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Retrieve cached user preferences
  Future<UserPreferences> getCachedPreferences() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_preferencesKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return UserPreferences.defaultPreferences();
      }
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserPreferences.fromMap(decoded);
    } catch (_) {
      return UserPreferences.defaultPreferences();
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await _getPrefs();
      final str = prefs.getString(_lastSyncKey);
      return str != null ? DateTime.tryParse(str) : null;
    } catch (_) {
      return null;
    }
  }
}
