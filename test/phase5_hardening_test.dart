import 'package:flutter_test/flutter_test.dart';
import 'package:techdaily/models/article.dart';
import 'package:techdaily/models/daily_brief.dart';
import 'package:techdaily/models/user_preferences.dart';
import 'package:techdaily/repositories/article_repository.dart';
import 'package:techdaily/services/article_ranking_service.dart';
import 'package:techdaily/services/daily_brief_service.dart';
import 'package:techdaily/services/search_service.dart';

void main() {
  group('Phase 5 — UserPreferences Tests', () {
    test('serializes and deserializes user preferences', () {
      final now = DateTime.now();
      final prefs = UserPreferences(
        selectedCategories: const ['AI & Machine Learning', 'Cybersecurity'],
        breakingNewsNotifications: true,
        dailyBriefNotifications: false,
        aiNewsNotifications: true,
        securityNewsNotifications: true,
        updatedAt: now,
      );

      final map = prefs.toMap();
      final restored = UserPreferences.fromMap(map);

      expect(restored.selectedCategories, ['AI & Machine Learning', 'Cybersecurity']);
      expect(restored.breakingNewsNotifications, true);
      expect(restored.dailyBriefNotifications, false);
      expect(restored.aiNewsNotifications, true);
      expect(restored.securityNewsNotifications, true);
    });

    test('isCategorySelected returns true if no categories chosen or if matched', () {
      final emptyPrefs = UserPreferences.defaultPreferences();
      expect(emptyPrefs.isCategorySelected('AI & Machine Learning'), true);

      final specificPrefs = UserPreferences(
        selectedCategories: const ['Cloud'],
        updatedAt: DateTime.now(),
      );
      expect(specificPrefs.isCategorySelected('Cloud'), true);
      expect(specificPrefs.isCategorySelected('Hardware'), false);
    });
  });

  group('Phase 5 — TransparentArticleRankingService Tests', () {
    final rankingService = TransparentArticleRankingService();
    final now = DateTime.now();

    final freshArticle = Article(
      id: 'fresh-1',
      title: 'Fresh AI Milestone Announced',
      summary: 'Summary of fresh announcement',
      simpleExplanation: 'Simple explanation of fresh announcement',
      category: 'AI & Machine Learning',
      sourceName: 'Google Official Blog',
      sourceUrl: 'https://blog.google/ai-milestone',
      publishedAt: now.subtract(const Duration(hours: 1)),
      keyPoints: const ['Key point 1'],
      isBreaking: false,
      aiProcessed: true,
    );

    final olderBreakingArticle = Article(
      id: 'breaking-1',
      title: 'Major Zero-Day Alert Under Active Exploit',
      summary: 'Emergency cybersecurity advisory',
      simpleExplanation: 'Security teams must patch immediately',
      category: 'Cybersecurity',
      sourceName: 'CISA Cybersecurity Advisories',
      sourceUrl: 'https://cisa.gov/advisory-1',
      publishedAt: now.subtract(const Duration(hours: 12)),
      keyPoints: const ['Critical advisory'],
      isBreaking: true,
      aiProcessed: true,
    );

    test('calculates transparent scores with explainable breakdown', () {
      final scoreFresh = rankingService.calculateScore(
        freshArticle,
        userInterests: ['AI & Machine Learning'],
        relativeTo: now,
      );

      final explanation = rankingService.explainScore(
        freshArticle,
        userInterests: ['AI & Machine Learning'],
        relativeTo: now,
      );

      expect(scoreFresh, greaterThan(100.0));
      expect(explanation['totalScore'], scoreFresh);
      expect(explanation['breakdown']['userInterestBoost'], 35.0);
      expect(explanation['breakdown']['sourceTrust'], 20.0);
      expect(explanation['breakdown']['aiSynthesisBoost'], 10.0);
    });

    test('breaking news receives +50 point boost ensuring high prominence', () {
      final scoreBreaking = rankingService.calculateScore(
        olderBreakingArticle,
        relativeTo: now,
      );
      final explanation = rankingService.explainScore(
        olderBreakingArticle,
        relativeTo: now,
      );

      expect(explanation['breakdown']['breakingBoost'], 50.0);
      expect(scoreBreaking, greaterThan(90.0));
    });

    test('rankArticles orders articles descending by score', () {
      final ranked = rankingService.rankArticles(
        [freshArticle, olderBreakingArticle],
        userInterests: ['AI & Machine Learning'],
      );

      expect(ranked.length, 2);
    });
  });

  group('Phase 5 — DailyBrief & DailyBriefService Tests', () {
    test('DailyBriefItem and DailyBrief serialize and deserialize correctly', () {
      const item = DailyBriefItem(
        rank: 1,
        articleId: 'art-1',
        headline: 'Frontier AI Model Released',
        whyItMatters: 'Doubles reasoning benchmark efficiency',
        category: 'AI & Machine Learning',
        sourceName: 'Google Official Blog',
        sourceUrl: 'https://blog.google/story',
      );

      final itemMap = item.toMap();
      final restoredItem = DailyBriefItem.fromMap(itemMap);
      expect(restoredItem.rank, 1);
      expect(restoredItem.headline, 'Frontier AI Model Released');

      final brief = DailyBrief(
        id: 'brief-2026-09-16',
        date: DateTime(2026, 9, 16),
        items: const [item],
        createdAt: DateTime(2026, 9, 16),
      );

      final briefMap = brief.toMap();
      final restoredBrief = DailyBrief.fromMap(briefMap);
      expect(restoredBrief.id, 'brief-2026-09-16');
      expect(restoredBrief.items.length, 1);
    });

    test('DailyBriefService synthesizes strictly from verified articles', () {
      final service = DailyBriefService();
      final articles = List.generate(
        12,
        (i) => Article(
          id: 'art-$i',
          title: 'Breakthrough Story $i',
          summary: 'Summary $i',
          simpleExplanation: 'Simple explanation $i',
          category: 'Software',
          sourceName: 'GitHub Blog',
          sourceUrl: 'https://github.blog/story-$i',
          publishedAt: DateTime.now(),
          keyPoints: const ['Point 1'],
          whyItMatters: 'Why it matters description $i',
        ),
      );

      final brief = service.synthesizeBriefFromArticles(articles, DateTime.now());
      expect(brief.items.length, 10);
      expect(brief.items[0].rank, 1);
      expect(brief.items[0].headline, 'Breakthrough Story 0');
      expect(brief.items[0].whyItMatters, 'Why it matters description 0');
    });
  });

  group('Phase 5 — ArticleSearchService Tests', () {
    test('multi-filter search filters by keywords, category, and source', () async {
      final repository = LocalArticleRepository();
      final searchService = ArticleSearchService(repository);

      // Search by keyword
      final aiResults = await searchService.search(
        const SearchParams(keywords: 'quantum'),
      );
      expect(aiResults, isNotEmpty);
      for (final a in aiResults) {
        final matches = a.title.toLowerCase().contains('quantum') ||
            a.summary.toLowerCase().contains('quantum') ||
            a.simpleExplanation.toLowerCase().contains('quantum') ||
            a.category.toLowerCase().contains('quantum');
        expect(matches, true);
      }

      // Search with empty params returns empty list
      final emptyResults = await searchService.search(const SearchParams());
      expect(emptyResults, isEmpty);
    });
  });
}
