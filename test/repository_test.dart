import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techdaily/repositories/article_repository.dart';
import 'package:techdaily/services/local_article_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalArticleRepository Tests', () {
    late LocalArticleRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = LocalArticleRepository(articleService: LocalArticleService());
    });

    test('getArticles returns non-empty list of demo articles', () async {
      final articles = await repository.getArticles();
      expect(articles.length, greaterThanOrEqualTo(15));
    });

    test('getBreakingNews returns breaking items', () async {
      final breaking = await repository.getBreakingNews();
      expect(breaking, isNotEmpty);
      for (final a in breaking) {
        expect(a.isBreaking, isTrue);
      }
    });

    test('getArticlesByCategory filters appropriately', () async {
      final aiArticles = await repository.getArticlesByCategory('AI & Machine Learning');
      expect(aiArticles, isNotEmpty);
      for (final a in aiArticles) {
        expect(a.category, 'AI & Machine Learning');
      }
    });

    test('searchArticles finds relevant queries', () async {
      final results = await repository.searchArticles('quantum');
      expect(results, isNotEmpty);
      expect(results.any((a) => a.title.toLowerCase().contains('quantum') || a.summary.toLowerCase().contains('quantum')), isTrue);
    });

    test('searchArticles returns empty for unmatched queries', () async {
      final results = await repository.searchArticles('nonexistentgibberish12345');
      expect(results, isEmpty);
    });

    test('bookmark toggling works as expected', () async {
      const testId = 'demo-ai-01';
      const userId = 'user-test-123';
      expect(repository.isArticleSaved(testId), isFalse);

      // Toggle ON
      final saved1 = await repository.toggleSaveArticle(userId, testId);
      expect(saved1, isTrue);
      expect(repository.isArticleSaved(testId), isTrue);

      final savedArticles = await repository.getSavedArticles(userId);
      expect(savedArticles.any((a) => a.id == testId), isTrue);

      // Toggle OFF
      final saved2 = await repository.toggleSaveArticle(userId, testId);
      expect(saved2, isFalse);
      expect(repository.isArticleSaved(testId), isFalse);
    });
  });
}
