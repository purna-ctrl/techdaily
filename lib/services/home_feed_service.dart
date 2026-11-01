import '../models/article.dart';
import 'article_ranking_service.dart';

/// A category block on the home screen.
class HomeCategorySection {
  final String title;
  final String categoryName;
  final List<Article> articles;

  const HomeCategorySection({
    required this.title,
    required this.categoryName,
    required this.articles,
  });
}

/// Everything the home screen shows, with each article used at most once.
class HomeFeed {
  final List<Article> breaking;
  final Article? lead;
  final List<Article> trending;
  final List<Article> india;
  final List<Article> thingsToKnow;
  final List<HomeCategorySection> sections;
  final List<Article> all;

  const HomeFeed({
    required this.breaking,
    required this.lead,
    required this.trending,
    required this.india,
    required this.thingsToKnow,
    required this.sections,
    required this.all,
  });

  static const empty = HomeFeed(
    breaking: [],
    lead: null,
    trending: [],
    india: [],
    thingsToKnow: [],
    sections: [],
    all: [],
  );

  bool get isEmpty => all.isEmpty;

  /// Ids shown anywhere on the page (used by tests to prove no duplicates).
  List<String> get placedIds => [
        ...breaking.map((a) => a.id),
        if (lead != null) lead!.id,
        ...trending.map((a) => a.id),
        ...india.map((a) => a.id),
        ...thingsToKnow.map((a) => a.id),
        for (final s in sections) ...s.articles.map((a) => a.id),
      ];
}

/// Builds the home layout from a flat list of articles. Sections are filled in
/// priority order and an article placed in one section is never repeated in
/// another (Lead → Breaking → Trending → India → Things to know → categories).
class HomeFeedComposer {
  final IArticleRankingService rankingService;

  HomeFeedComposer({IArticleRankingService? rankingService})
      : rankingService = rankingService ?? TransparentArticleRankingService();

  static const List<(String, List<String>)> categoryOrder = [
    ('AI & Machine Learning', ['AI & Machine Learning']),
    ('Software', ['Software']),
    ('Hardware', ['Hardware']),
    ('Smartphones', ['Smartphones']),
    ('Cybersecurity', ['Cybersecurity']),
    ('Cloud', ['Cloud']),
    ('Startups', ['Startups']),
    ('Companies', ['Companies']),
    ('Science & Space', ['Science', 'Space']),
  ];

  HomeFeed compose(
    List<Article> articles, {
    List<String> userInterests = const [],
    int breakingLimit = 3,
    int trendingLimit = 5,
    int indiaLimit = 4,
    int thingsLimit = 5,
    int perSectionLimit = 4,
  }) {
    // Remove duplicate ids defensively (e.g. the same doc arriving twice).
    final seenInput = <String>{};
    final unique = <Article>[
      for (final a in articles)
        if (a.id.isNotEmpty && seenInput.add(a.id)) a,
    ];
    if (unique.isEmpty) return HomeFeed.empty;

    final ranked = rankingService.rankArticles(unique, userInterests: userInterests);
    final used = <String>{};

    List<Article> take(Iterable<Article> source, int limit) {
      final out = <Article>[];
      for (final a in source) {
        if (out.length >= limit) break;
        if (used.add(a.id)) out.add(a);
      }
      return out;
    }

    final byRecency = List<Article>.from(unique)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // The lead is the top-ranked story (breaking stories rank highest); the
    // remaining breaking stories get their own strip.
    final leadList = take(ranked, 1);
    final breaking = take(byRecency.where((a) => a.isBreaking), breakingLimit);
    final trending = take(
      rankingService.getTrendingArticles(unique, limit: unique.length),
      trendingLimit,
    );
    final india = take(ranked.where((a) => a.isIndia), indiaLimit);
    final things = take(ranked, thingsLimit);

    final sections = <HomeCategorySection>[];
    for (final (title, cats) in categoryOrder) {
      final lower = cats.map((c) => c.toLowerCase()).toSet();
      final items = take(
        byRecency.where((a) => lower.contains(a.category.toLowerCase())),
        perSectionLimit,
      );
      if (items.isNotEmpty) {
        sections.add(HomeCategorySection(
          title: title,
          categoryName: cats.first,
          articles: items,
        ));
      }
    }

    return HomeFeed(
      breaking: breaking,
      lead: leadList.isEmpty ? null : leadList.first,
      trending: trending,
      india: india,
      thingsToKnow: things,
      sections: sections,
      all: ranked,
    );
  }
}
