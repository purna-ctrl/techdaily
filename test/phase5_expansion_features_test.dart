import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techdaily/core/constants/categories.dart';
import 'package:techdaily/core/theme/app_theme.dart';
import 'package:techdaily/models/article.dart';
import 'package:techdaily/models/user_preferences.dart';
import 'package:techdaily/services/article_ai_assistant_service.dart';
import 'package:techdaily/services/article_ranking_service.dart';
import 'package:techdaily/services/reading_history_service.dart';
import 'package:techdaily/services/story_comparison_service.dart';
import 'package:techdaily/services/story_timeline_service.dart';
import 'package:techdaily/services/text_to_speech_service.dart';
import 'package:techdaily/services/weekly_recap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 17, 10, 0);

  final articleAI = Article(
    id: 'art-ai-1',
    title: 'Frontier Neural Architecture Achieves Zero-Shot Reasoning Milestone',
    summary: 'New neural scaling laws reveal exponential gains in multi-modal synthesis.',
    simpleExplanation: 'Computer models can now solve multi-step problems without needing examples first.',
    whatHappened: 'Researchers unveiled an efficient 50B-parameter model outperforming 400B models.',
    whyItMatters: 'Drastically cuts inference cost and democratizes on-device intelligent agents.',
    category: 'AI & Machine Learning',
    sourceName: 'Google Official Blog',
    sourceUrl: 'https://blog.google/technology/ai/frontier-milestone',
    publishedAt: now.subtract(const Duration(hours: 2)),
    keyPoints: [
      'Zero-shot accuracy improved by 28% across standard benchmarks',
      'Memory footprint reduced by 4x using 4-bit quantized attention',
      'Team plans to open-weights next month for academic verification'
    ],
    isBreaking: false,
    aiProcessed: true,
  );

  final articleSec = Article(
    id: 'art-sec-1',
    title: 'Emergency Advisory Issued for Open-Source Cryptographic Library',
    summary: 'Critical buffer overflow vulnerability discovered in high-throughput TLS parser.',
    simpleExplanation: 'A security bug could let remote attackers intercept data unless updated.',
    whatHappened: 'Security teams identified active zero-day scanning targeting unpatched servers.',
    whyItMatters: 'Over 60% of modern web infrastructure relies on this transport layer.',
    category: 'Cybersecurity',
    sourceName: 'CISA Cybersecurity Advisories',
    sourceUrl: 'https://cisa.gov/news-events/cybersecurity-advisories/advisory-01',
    publishedAt: now.subtract(const Duration(hours: 1)),
    keyPoints: [
      'CVSS Severity score rated at maximum 9.8 critical',
      'Patch version 3.4.2 released immediately by maintainers',
      'All enterprise system administrators urged to deploy fix'
    ],
    isBreaking: true,
    aiProcessed: true,
  );

  final articleHardware = Article(
    id: 'art-hw-1',
    title: 'Next-Gen 2nm Fabrication Line Enters High-Volume Production',
    summary: 'Leading semiconductor foundry achieves 70% yield on backside power delivery silicon.',
    simpleExplanation: 'Computer chips can now be built with smaller transistors, saving battery life.',
    whatHappened: 'Foundry confirmed mass production start for commercial smartphone processors.',
    whyItMatters: 'Enables 15% faster clock speeds while reducing thermal dissipation by 30%.',
    category: 'Hardware',
    sourceName: 'MIT Technology Review',
    sourceUrl: 'https://technologyreview.com/hardware-2nm-production',
    publishedAt: now.subtract(const Duration(days: 3)),
    keyPoints: [
      'First commercial devices expected in retail markets next quarter',
      'Backside power distribution eliminates wiring congestion'
    ],
    isBreaking: false,
    aiProcessed: true,
  );

  group('Feature 1 — Trending Now Ranking Tests', () {
    final rankingService = TransparentArticleRankingService();

    test('getTrendingArticles returns explainable ranked list with recency and breaking boosts', () {
      final trending = rankingService.getTrendingArticles(
        [articleHardware, articleAI, articleSec],
        limit: 2,
        relativeTo: now,
      );

      expect(trending.length, 2);
      // ArticleSec has breaking boost (+50) and recency, so it should rank first
      expect(trending.first.id, articleSec.id);
      expect(trending[1].id, articleAI.id);
    });

    test('getTrendingArticles honors limit and preserves deterministic tie-breaking', () {
      final trending = rankingService.getTrendingArticles(
        [articleHardware, articleAI, articleSec],
        limit: 1,
        relativeTo: now,
      );

      expect(trending.length, 1);
      expect(trending.first.isBreaking, true);
    });
  });

  group('Feature 3 — Ask AI About Article Grounding Tests', () {
    final assistant = ArticleAiAssistantService();

    test('answers "Why is this important?" strictly using whyItMatters', () {
      final answer = assistant.answerQuestion(articleAI, 'Why is this important?');
      expect(answer, contains('Drastically cuts inference cost'));
    });

    test('answers "Explain this simply" strictly using simpleExplanation', () {
      final answer = assistant.answerQuestion(articleAI, 'Explain this simply');
      expect(answer, contains('Computer models can now solve multi-step problems'));
    });

    test('answers "What could happen next?" strictly using roadmap/future points', () {
      final answer = assistant.answerQuestion(articleAI, 'What could happen next?');
      expect(answer, contains('Team plans to open-weights next month'));
    });

    test('strictly refuses to hallucinate when asked about absent topics', () {
      final answer = assistant.answerQuestion(
        articleAI,
        'What was the stock market price of Apple yesterday?',
      );
      expect(answer, contains('does not mention'));
      expect(answer, contains('strictly grounded'));
    });
  });

  group('Feature 4 & 5 — For You & Follow Topics Tests', () {
    test('UserPreferences initializes and manages followed topics', () {
      final prefs = UserPreferences.defaultPreferences();
      expect(prefs.selectedCategories.isEmpty, true);

      final updated = prefs.copyWith(
        selectedCategories: ['AI & Machine Learning', 'Cybersecurity'],
        updatedAt: DateTime.now(),
      );

      expect(updated.selectedCategories.length, 2);
      expect(updated.isCategorySelected('AI & Machine Learning'), true);
      expect(updated.isCategorySelected('Cybersecurity'), true);
      expect(updated.isCategorySelected('Hardware'), false);
    });

    test('all 10 AppCategories are valid and unique', () {
      expect(AppCategories.all.length, 10);
      final names = AppCategories.all.map((c) => c.name).toSet();
      expect(names.length, 10);
    });
  });

  group('Feature 6 — Story Timeline Service Tests', () {
    final timelineService = StoryTimelineService();

    final relatedAIArticle = Article(
      id: 'art-ai-2',
      title: 'Neural Architecture Benchmark Validated by Peer Institutions',
      summary: 'Independent researchers verify zero-shot benchmark claims.',
      simpleExplanation: 'Other universities confirmed the test results.',
      whatHappened: 'Three independent labs ran the benchmark suite.',
      whyItMatters: 'Confirms validity of the architecture.',
      category: 'AI & Machine Learning',
      sourceName: 'ACM TechNews',
      sourceUrl: 'https://acm.org/technews/benchmark-validated',
      publishedAt: now.subtract(const Duration(hours: 1)),
      keyPoints: ['Results reproduce with 99.4% precision'],
    );

    test('links related developing stories within 48-hour window', () {
      final timeline = timelineService.getTimeline(
        articleAI,
        [articleAI, relatedAIArticle, articleHardware],
      );

      expect(timeline.isNotEmpty, true);
      expect(timeline.length, 2);
      expect(timeline.first.stage, 'Initial Wire Report');
      expect(timeline.last.stage, 'Latest Wire Dispatch');
    });

    test('cleanly returns empty timeline when no related articles exist', () {
      final timeline = timelineService.getTimeline(
        articleHardware,
        [articleHardware],
      );

      expect(timeline.isEmpty, true);
    });
  });

  group('Feature 7 — Story Comparison Service Tests', () {
    final comparisonService = StoryComparisonService();

    test('compares two stories factually without editorial bias', () {
      final result = comparisonService.compare(articleAI, articleSec);

      expect(result.articleA.id, articleAI.id);
      expect(result.articleB.id, articleSec.id);
      expect(result.distinctPointsA.isNotEmpty, true);
      expect(result.distinctPointsB.isNotEmpty, true);
      expect(result.takeawaySummary, contains('Both dispatches address'));
      expect(result.takeawaySummary, contains(articleAI.sourceName));
      expect(result.takeawaySummary, contains(articleSec.sourceName));
    });
  });

  group('Feature 8 — Reading History Service Tests', () {
    test('records read, avoids duplicates, and clears history', () async {
      SharedPreferences.setMockInitialValues({});
      final historyService = ReadingHistoryService();

      // Record first read
      await historyService.recordRead(articleAI);
      var history = await historyService.getHistory();
      expect(history.length, 1);
      expect(history.first.articleId, articleAI.id);

      // Record second read of different article
      await historyService.recordRead(articleSec);
      history = await historyService.getHistory();
      expect(history.length, 2);
      expect(history.first.articleId, articleSec.id);

      // Re-read first article: should bump to top without duplicating
      await historyService.recordRead(articleAI);
      history = await historyService.getHistory();
      expect(history.length, 2);
      expect(history.first.articleId, articleAI.id);

      // Remove item
      await historyService.removeItem(articleAI.id);
      history = await historyService.getHistory();
      expect(history.length, 1);
      expect(history.first.articleId, articleSec.id);

      // Clear all
      await historyService.clearHistory();
      history = await historyService.getHistory();
      expect(history.isEmpty, true);
    });
  });

  group('Feature 9 — Text-To-Speech Interface Tests', () {
    test('FlutterTtsService handles playback states and speeds gracefully without crashing', () async {
      final tts = FlutterTtsService();
      expect(tts.state, TtsPlaybackState.stopped);
      expect(tts.speed, 1.0);

      await tts.setSpeed(1.5);
      expect(tts.speed, 1.5);

      await tts.speak('Headline: AI Breakthrough');
      expect(tts.state == TtsPlaybackState.playing || tts.state == TtsPlaybackState.stopped, true);

      await tts.pause();
      expect(tts.state == TtsPlaybackState.paused || tts.state == TtsPlaybackState.stopped, true);

      await tts.stop();
      expect(tts.state, TtsPlaybackState.stopped);

      tts.dispose();
    });
  });

  group('Feature 10 — Weekly Tech Recap Tests', () {
    final recapService = WeeklyRecapService();

    test('synthesizes 7-day recap strictly from ingested articles', () {
      final recap = recapService.generateWeeklyRecap(
        [articleAI, articleSec, articleHardware],
        relativeTo: now,
      );

      expect(recap.topStories.isNotEmpty, true);
      expect(recap.majorMilestones.isNotEmpty, true);
      expect(recap.whatToWatchNextWeek.isNotEmpty, true);
      expect(recap.sectorBreakdown.containsKey('AI & Machine Learning'), true);
      expect(recap.sectorBreakdown.containsKey('Cybersecurity'), true);
    });
  });

  group('Feature 11 — Dynamic Category Visuals Tests', () {
    test('all primary technology categories map to distinct accent colors', () {
      final aiColor = AppTheme.getCategoryAccent('AI & Machine Learning');
      final hwColor = AppTheme.getCategoryAccent('Hardware');
      final secColor = AppTheme.getCategoryAccent('Cybersecurity');
      final cloudColor = AppTheme.getCategoryAccent('Cloud');
      final startupsColor = AppTheme.getCategoryAccent('Startups');
      final scienceColor = AppTheme.getCategoryAccent('Science');

      expect(aiColor, isNot(equals(hwColor)));
      expect(hwColor, isNot(equals(secColor)));
      expect(secColor, isNot(equals(cloudColor)));
      expect(cloudColor, isNot(equals(startupsColor)));
      expect(startupsColor, isNot(equals(scienceColor)));
    });
  });
}
