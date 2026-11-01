import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article.dart';
import '../models/daily_brief.dart';
import 'offline_cache_service.dart';

class DailyBriefService {
  final FirebaseFirestore? firestore;
  final OfflineCacheService _cacheService;

  DailyBriefService({
    this.firestore,
    OfflineCacheService? cacheService,
  }) : _cacheService = cacheService ?? OfflineCacheService();

  static String generateDateId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'brief-$y-$m-$d';
  }

  /// Retrieves today's Daily Brief from Firestore, local cache, or synthesizes from trusted articles.
  Future<DailyBrief> getTodayBrief({List<Article>? fallbackArticles}) async {
    final now = DateTime.now();
    final dateId = generateDateId(now);

    // 1. Try Firestore if available
    if (firestore != null) {
      try {
        final doc = await firestore!.collection('dailyBriefs').doc(dateId).get();
        if (doc.exists && doc.data() != null) {
          final brief = DailyBrief.fromMap(doc.data()!, docId: doc.id);
          await _cacheService.cacheDailyBrief(brief);
          return brief;
        }
      } catch (_) {
        // Fall back to cache / synthesis
      }
    }

    // 2. Try cached brief
    final cached = await _cacheService.getCachedDailyBrief();
    if (cached != null &&
        cached.date.year == now.year &&
        cached.date.month == now.month &&
        cached.date.day == now.day) {
      return cached;
    }

    // 3. Synthesize strictly from verified stored articles (Zero Hallucination)
    final articles = fallbackArticles ?? await _cacheService.getCachedArticles();
    final synthesized = synthesizeBriefFromArticles(articles, now);
    await _cacheService.cacheDailyBrief(synthesized);
    return synthesized;
  }

  /// Synthesizes a daily brief strictly from provided verified articles.
  DailyBrief synthesizeBriefFromArticles(List<Article> articles, DateTime date) {
    final dateId = generateDateId(date);
    // Take up to 10 top stories
    final topArticles = articles.take(10).toList();

    final items = <DailyBriefItem>[];
    for (int i = 0; i < topArticles.length; i++) {
      final a = topArticles[i];
      final whyItMatters = a.whyItMatters.isNotEmpty
          ? a.whyItMatters
          : (a.simpleExplanation.isNotEmpty
              ? a.simpleExplanation
              : a.summary);

      items.add(
        DailyBriefItem(
          rank: i + 1,
          articleId: a.id,
          headline: a.title,
          whyItMatters: whyItMatters,
          category: a.category,
          sourceName: a.sourceName,
          sourceUrl: a.sourceUrl,
          whatHappened: a.whatHappened.isNotEmpty ? a.whatHappened : a.summary,
          keyPoints: a.keyPoints,
        ),
      );
    }

    return DailyBrief(
      id: dateId,
      date: date,
      title: 'TODAY IN TECH',
      subtitle: '${items.length} essential technology developments curated from verified primary wires.',
      items: items,
      createdAt: DateTime.now(),
    );
  }
}
