import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/reading_history_item.dart';

class ReadingHistoryService {
  static const String _storageKey = 'techdaily_reading_history_v1';
  final SharedPreferences? prefs;

  ReadingHistoryService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<ReadingHistoryItem>> getHistory() async {
    try {
      final p = await _getPrefs();
      final jsonStr = p.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((m) => ReadingHistoryItem.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordRead(Article article) async {
    try {
      final list = await getHistory();
      // Remove previous entry of the same article to avoid duplicates
      list.removeWhere((item) => item.articleId == article.id);

      final newItem = ReadingHistoryItem(
        articleId: article.id,
        title: article.title,
        category: article.category,
        sourceName: article.sourceName,
        readAt: DateTime.now(),
        readingTimeMinutes: article.readingTimeMinutes,
      );

      // Prepend at the top
      list.insert(0, newItem);

      // Keep up to 100 most recent items
      final trimmed = list.take(100).toList();
      final p = await _getPrefs();
      final jsonStr = jsonEncode(trimmed.map((e) => e.toMap()).toList());
      await p.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> removeItem(String articleId) async {
    try {
      final list = await getHistory();
      list.removeWhere((item) => item.articleId == articleId);
      final p = await _getPrefs();
      await p.setString(_storageKey, jsonEncode(list.map((e) => e.toMap()).toList()));
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final p = await _getPrefs();
      await p.remove(_storageKey);
    } catch (_) {}
  }
}
