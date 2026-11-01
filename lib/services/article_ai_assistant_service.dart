import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/article.dart';

/// Where an Ask AI answer came from.
enum AiAnswerSource { backend, localFallback }

class AiAnswer {
  final String text;
  final AiAnswerSource source;
  const AiAnswer(this.text, this.source);
}

class ArticleAiAssistantService {
  final http.Client? _client;
  final String endpoint;
  final Duration timeout;

  ArticleAiAssistantService({
    http.Client? client,
    this.endpoint = kAskArticleEndpoint,
    this.timeout = kAskArticleTimeout,
  }) : _client = client; // ignore: prefer_initializing_formals

  /// Asks the backend (`POST {articleId, question}` → `{answer}`).
  /// On any failure (network, non-200, bad JSON, empty answer, timeout) it
  /// falls back to the grounded on-device [answerQuestion].
  Future<AiAnswer> ask(Article article, String question) async {
    final q = question.trim();
    if (q.isEmpty || article.id.isEmpty || endpoint.isEmpty) {
      return AiAnswer(answerQuestion(article, question), AiAnswerSource.localFallback);
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'articleId': article.id, 'question': q}),
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['answer'] is String) {
          final answer = (decoded['answer'] as String).trim();
          if (answer.isNotEmpty) {
            return AiAnswer(answer, AiAnswerSource.backend);
          }
        }
      }
    } catch (_) {
      // Fall through to the grounded local answer.
    } finally {
      if (_client == null) client.close();
    }
    return AiAnswer(answerQuestion(article, question), AiAnswerSource.localFallback);
  }

  static const List<String> suggestedPrompts = [
    'Why is this important?',
    'Explain this simply',
    'What does this mean for developers / users / business?',
    'What could happen next?',
  ];

  /// Answers questions grounded strictly in the provided article.
  /// Does not hallucinate or speculate on facts outside the text.
  String answerQuestion(Article article, String rawQuestion) {
    final query = rawQuestion.trim().toLowerCase();
    if (query.isEmpty) {
      return 'Please enter a question about this article.';
    }

    // 1. "Why is this important?"
    if (query.contains('important') || query.contains('why it matters') || query.contains('why is this')) {
      if (article.whyItMatters.isNotEmpty) {
        return article.whyItMatters;
      } else if (article.keyPoints.isNotEmpty) {
        return 'According to the report, this is important because:\n• ${article.keyPoints.join('\n• ')}';
      } else {
        return 'The report highlights the following key significance: ${article.summary}';
      }
    }

    // 2. "Explain this simply"
    if (query.contains('simply') || query.contains('simple') || query.contains('in simple words') || query.contains('eli5')) {
      if (article.simpleExplanation.isNotEmpty) {
        return article.simpleExplanation;
      }
      return 'In simple terms: ${article.summary}';
    }

    // 3. "What does this mean for developers / users / business?"
    if (query.contains('mean for') || query.contains('developer') || query.contains('business') || query.contains('impact')) {
      final impact = article.whyItMatters.isNotEmpty ? article.whyItMatters : article.summary;
      final keyTakeaways = article.keyPoints.isNotEmpty
          ? '\n\nKey takeaways from the text:\n• ${article.keyPoints.join('\n• ')}'
          : '';
      return 'Direct implications cited in this article:\n$impact$keyTakeaways\n\nNote: The article from ${article.sourceName} focuses strictly on verified developments and does not introduce unverified secondary forecasts.';
    }

    // 4. "What could happen next?"
    if (query.contains('next') || query.contains('future') || query.contains('happen next') || query.contains('timeline')) {
      // Look for forward-looking keywords in whatHappened and keyPoints
      final forwardKeywords = ['will', 'plans', 'scheduled', 'upcoming', 'next', 'roadmap', 'expected'];
      final matchingPoints = article.keyPoints.where((p) {
        final lp = p.toLowerCase();
        return forwardKeywords.any((k) => lp.contains(k));
      }).toList();

      if (matchingPoints.isNotEmpty) {
        return 'The article outlines the following anticipated steps:\n• ${matchingPoints.join('\n• ')}';
      }

      return 'The article reports on confirmed developments (${article.whatHappened.isNotEmpty ? article.whatHappened : article.title}), but does not outline speculative future events or unconfirmed roadmap dates.';
    }

    // 5. General search in article body
    // Extract significant query words (> 3 chars)
    final queryWords = query
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !['what', 'when', 'where', 'which', 'about', 'this', 'does', 'have', 'from', 'with'].contains(w))
        .toList();

    if (queryWords.isEmpty) {
      return 'Based on the article: ${article.summary}';
    }

    // Check matches in key points
    final matchedPoints = article.keyPoints.where((point) {
      final lp = point.toLowerCase();
      return queryWords.any((word) => lp.contains(word));
    }).toList();

    if (matchedPoints.isNotEmpty) {
      return 'From the article details:\n• ${matchedPoints.join('\n• ')}';
    }

    // Check whatHappened / whyItMatters
    if (queryWords.any((w) => article.whatHappened.toLowerCase().contains(w))) {
      return 'According to the article: ${article.whatHappened}';
    }
    if (queryWords.any((w) => article.whyItMatters.toLowerCase().contains(w))) {
      return 'According to the article: ${article.whyItMatters}';
    }

    // Strictly no hallucination
    return 'The provided report from ${article.sourceName} does not mention details regarding "$rawQuestion". This assistant is strictly grounded in verified article facts and cannot speculate beyond published text.';
  }
}
