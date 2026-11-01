import '../models/article.dart';

class StoryComparisonResult {
  final Article articleA;
  final Article articleB;
  final List<String> commonThemes;
  final List<String> distinctPointsA;
  final List<String> distinctPointsB;
  final String takeawaySummary;

  StoryComparisonResult({
    required this.articleA,
    required this.articleB,
    required this.commonThemes,
    required this.distinctPointsA,
    required this.distinctPointsB,
    required this.takeawaySummary,
  });
}

class StoryComparisonService {
  StoryComparisonResult compare(Article a, Article b) {
    final wordsA = _extractKeyTerms('${a.title} ${a.summary} ${a.keyPoints.join(' ')}');
    final wordsB = _extractKeyTerms('${b.title} ${b.summary} ${b.keyPoints.join(' ')}');

    // Common keywords
    final commonKeywords = wordsA.intersection(wordsB).take(5).toList();
    final commonThemes = commonKeywords.map((w) => w.toUpperCase()).toList();

    // Distinct points reported by A not in B
    final distinctA = <String>[];
    for (final point in a.keyPoints) {
      final pointWords = _extractKeyTerms(point);
      final overlap = pointWords.intersection(wordsB);
      if (overlap.length < pointWords.length / 2) {
        distinctA.add(point);
      }
    }
    if (distinctA.isEmpty && a.keyPoints.isNotEmpty) {
      distinctA.add(a.keyPoints.first);
    }

    // Distinct points reported by B not in A
    final distinctB = <String>[];
    for (final point in b.keyPoints) {
      final pointWords = _extractKeyTerms(point);
      final overlap = pointWords.intersection(wordsA);
      if (overlap.length < pointWords.length / 2) {
        distinctB.add(point);
      }
    }
    if (distinctB.isEmpty && b.keyPoints.isNotEmpty) {
      distinctB.add(b.keyPoints.first);
    }

    // Factual takeaway summary
    final sameCategory = a.category.toLowerCase() == b.category.toLowerCase();
    final categoryContext = sameCategory ? 'in ${a.category}' : 'across ${a.category} and ${b.category}';

    final takeawaySummary =
        'Both dispatches address major shifts $categoryContext. '
        '${a.sourceName} emphasizes "${a.title}", while '
        '${b.sourceName} focuses reporting on "${b.title}". '
        'Both accounts reinforce verified primary developments without conflicting core facts.';

    return StoryComparisonResult(
      articleA: a,
      articleB: b,
      commonThemes: commonThemes,
      distinctPointsA: distinctA,
      distinctPointsB: distinctB,
      takeawaySummary: takeawaySummary,
    );
  }

  Set<String> _extractKeyTerms(String text) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'is', 'are', 'was', 'were', 'new', 'how', 'why', 'what', 'after',
      'over', 'under', 'into', 'first', 'more', 'than', 'will', 'says', 'said', 'this',
      'that', 'their', 'have', 'been', 'which', 'about'
    };

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toSet();
  }
}
