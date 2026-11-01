import 'package:flutter/foundation.dart';

abstract class IAnalyticsService {
  void logEvent(String eventName, [Map<String, dynamic>? parameters]);
  void logArticleOpened(String articleId, String category, String sourceName);
  void logCategoryOpened(String category);
  void logSearchUsed(String query, int resultsCount);
  void logArticleSaved(String articleId, bool isSaved);
  void logDailyBriefOpened();
}

class TechDailyAnalyticsService implements IAnalyticsService {
  final bool enabled;

  TechDailyAnalyticsService({this.enabled = true});

  @override
  void logEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (!enabled) return;
    // Strictly anonymous product metrics; never log passwords, tokens, or PII
    debugPrint('[Analytics] Event: $eventName, data: $parameters');
  }

  @override
  void logArticleOpened(String articleId, String category, String sourceName) {
    logEvent('article_opened', {
      'articleId': articleId,
      'category': category,
      'sourceName': sourceName,
    });
  }

  @override
  void logCategoryOpened(String category) {
    logEvent('category_opened', {'category': category});
  }

  @override
  void logSearchUsed(String query, int resultsCount) {
    logEvent('search_used', {
      'queryLength': query.trim().length,
      'resultsCount': resultsCount,
    });
  }

  @override
  void logArticleSaved(String articleId, bool isSaved) {
    logEvent('article_saved', {
      'articleId': articleId,
      'action': isSaved ? 'saved' : 'unsaved',
    });
  }

  @override
  void logDailyBriefOpened() {
    logEvent('daily_brief_opened');
  }
}
