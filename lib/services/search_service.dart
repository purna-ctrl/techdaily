import '../models/article.dart';
import '../repositories/article_repository.dart';

class SearchParams {
  final String keywords;
  final String? category;
  final String? source;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const SearchParams({
    this.keywords = '',
    this.category,
    this.source,
    this.startDate,
    this.endDate,
    this.limit = 50,
  });

  bool get isEmpty =>
      keywords.trim().isEmpty &&
      (category == null || category!.isEmpty) &&
      (source == null || source!.isEmpty);
}

abstract class ISearchService {
  Future<List<Article>> search(SearchParams params);
}

class ArticleSearchService implements ISearchService {
  final ArticleRepository _repository;

  ArticleSearchService(this._repository);

  @override
  Future<List<Article>> search(SearchParams params) async {
    if (params.isEmpty) return [];

    final cleanQuery = params.keywords.trim().toLowerCase();

    // 1. Fetch candidates from repository (bounded query, max 100 recent articles)
    List<Article> candidates;
    if (cleanQuery.isNotEmpty) {
      candidates = await _repository.searchArticles(cleanQuery);
    } else if (params.category != null && params.category!.isNotEmpty) {
      candidates = await _repository.getArticlesByCategory(params.category!);
    } else {
      candidates = await _repository.getArticles();
    }

    // 2. Apply filters across category, source, and date range
    return candidates.where((article) {
      // Category filter
      if (params.category != null && params.category!.isNotEmpty) {
        if (article.category.toLowerCase() != params.category!.toLowerCase()) {
          return false;
        }
      }

      // Source filter
      if (params.source != null && params.source!.isNotEmpty) {
        if (!article.sourceName.toLowerCase().contains(params.source!.toLowerCase())) {
          return false;
        }
      }

      // Start date filter
      if (params.startDate != null) {
        if (article.publishedAt.isBefore(params.startDate!)) {
          return false;
        }
      }

      // End date filter
      if (params.endDate != null) {
        if (article.publishedAt.isAfter(params.endDate!)) {
          return false;
        }
      }

      return true;
    }).take(params.limit).toList();
  }
}
