import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/constants/jargon.dart';
import '../../models/story.dart';

/// Where an answer came from.
enum AskSource { faq, jargon, story, remote, none }

class AskAnswer {
  final String text;
  final AskSource source;
  const AskAnswer(this.text, this.source);

  /// True when nothing in the story answered it (offer the sources instead).
  bool get unanswered => source == AskSource.none;
}

const String kAskNoAnswer =
    'Sorry — this story doesn’t say. The original reports may have more detail: tap “Read the sources” to check them.';

const _stop = {
  'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'it', 'this', 'that', 'these', 'those', 'of', 'to', 'in', 'on', 'for',
  'and', 'or', 'do', 'does', 'did', 'i', 'me', 'my', 'we', 'you', 'your', 'can', 'will', 'would', 'should', 'could', 'what',
  'whats', 'how', 'why', 'when', 'where', 'who', 'which', 'about', 'with', 'there', 'any', 'has', 'have', 'get', 'its', 'at',
  'by', 'from', 'as', 'if', 'so', 'than', 'then', 'just', 'also', 'mean', 'means', 'tell', 'please', 'story', 'news',
};

List<String> _tokens(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .split(RegExp(r'[^a-z0-9₹%]+'))
    .where((w) => w.length > 1 && !_stop.contains(w))
    .map((w) => w.length > 4 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
    .toList();

double _overlap(List<String> q, List<String> t) {
  if (q.isEmpty) return 0;
  final set = t.toSet();
  return q.where(set.contains).length / q.length;
}

List<String> _sentences(String t) =>
    t.split(RegExp(r'(?<=[.!?])\s+')).map((x) => x.trim()).where((x) => x.length > 3).toList();

const String kAskNotQuestion =
    'Try asking a question about this story — for example “Does this affect India?” or one of the questions above.';

/// Answers a reader's question from the story alone (no network): its FAQ,
/// the jargon dictionary, then the best-matching sentence of its sections.
AskAnswer answerLocally(Story s, String question) {
  final q = question.trim();
  if (q.isEmpty) return const AskAnswer(kAskNoAnswer, AskSource.none);
  final qt = _tokens(q);
  final lower = q.toLowerCase();

  // 1. The story's own FAQ.
  FaqItem? best;
  var bestScore = 0.0;
  for (final f in s.faq) {
    final sc = _overlap(qt, _tokens(f.q));
    if (sc > bestScore) {
      bestScore = sc;
      best = f;
    }
  }
  // A question must share most of its words (and at least two) with the FAQ question.
  final faqHits = best == null ? 0 : qt.where(_tokens(best.q).toSet().contains).length;
  if (best != null && bestScore >= 0.67 && (faqHits >= 2 || qt.length == 1)) {
    return AskAnswer(best.a, AskSource.faq);
  }

  // Statements / opinions ("reddit is useful") aren't questions: don't guess.
  final looksLikeQuestion = q.contains('?') ||
      RegExp(r'^(what|whats|how|why|when|where|who|which|is|are|was|will|can|could|should|does|do|did|has|have|explain|tell|define)\b')
          .hasMatch(lower);
  if (!looksLikeQuestion) return const AskAnswer(kAskNotQuestion, AskSource.none);

  // 2. "What is / what does X mean?" -> jargon dictionary.
  if (RegExp(r'\b(what|mean|meaning|explain|define)\b').hasMatch(lower)) {
    final hits = findJargon(q, max: 1);
    if (hits.isNotEmpty) {
      final e = hits.first.$3;
      return AskAnswer('${e.term}: ${e.meaning}${e.example != null ? ' For example: ${e.example}' : ''}', AskSource.jargon);
    }
  }

  // 3. Intent shortcuts onto the story's sections.
  final d = s.display;
  String? pick(String text) => text.trim().isEmpty ? null : text.trim();
  KeyNumber? kn(RegExp label) {
    for (final k in s.keyNumbers) {
      if (label.hasMatch(k.label.toLowerCase())) return k;
    }
    return null;
  }

  if (RegExp(r'\b(price|cost|costs|how much|₹|rupees|rs)\b').hasMatch(lower)) {
    final k = kn(RegExp(r'price|plan|fee|cost'));
    if (k != null) return AskAnswer('The reports mention ${k.value} (${k.label.toLowerCase()}).', AskSource.story);
  }
  if (RegExp(r'\b(when|date|launch date|sale date)\b').hasMatch(lower)) {
    final k = kn(RegExp(r'date|sale|launch'));
    if (k != null) return AskAnswer('The reports mention ${k.value}.', AskSource.story);
  }
  if (RegExp(r'\b(affect|affected|at risk|safe|impact)\b').hasMatch(lower)) {
    final t = pick(d.affectsWho);
    if (t != null) return AskAnswer(t, AskSource.story);
  }
  if (RegExp(r'\b(what (should|can) i do|what to do|how (do|can) i|steps?|protect)\b').hasMatch(lower)) {
    if (d.whatToDo.isNotEmpty) return AskAnswer(d.whatToDo.join(' '), AskSource.story);
    final t = pick(d.goodToKnow);
    if (t != null) return AskAnswer(t, AskSource.story);
  }
  if (RegExp(r'\b(why|matter|matters|important)\b').hasMatch(lower)) {
    final t = pick(d.whatItMeans);
    if (t != null) return AskAnswer(t, AskSource.story);
  }

  // 4. Best sentence anywhere in the story.
  final pool = <String>[
    ..._sentences(d.tldr),
    ..._sentences(d.whatHappened),
    ..._sentences(d.affectsWho),
    ...d.whatToDo,
    ..._sentences(d.goodToKnow),
    ..._sentences(d.whatItMeans),
    if (s.scam != null) ..._sentences(s.scam!.howItWorks),
    for (final f in s.faq) f.a,
  ];
  String? bestS;
  var bestN = 0;
  for (final t in pool) {
    final set = _tokens(t).toSet();
    final n = qt.where(set.contains).length;
    if (n > bestN) {
      bestN = n;
      bestS = t;
    }
  }
  // At least a third of the question's words (min 1, and 2 once the question has 5+ words).
  final need = qt.length >= 5 ? 2 : (qt.length / 3).ceil().clamp(1, 2);
  if (bestS != null && bestN >= need) return AskAnswer(bestS, AskSource.story);
  return const AskAnswer(kAskNoAnswer, AskSource.none);
}

/// Story context sent to the ask endpoint (the Worker answers only from it).
Map<String, dynamic> askContext(Story s) {
  final d = s.display;
  return {
    'headline': s.headline,
    'category': s.category,
    'tldr': d.tldr,
    'whatHappened': d.whatHappened,
    'affectsWho': d.affectsWho,
    'whatToDo': d.whatToDo,
    'goodToKnow': d.goodToKnow,
    'whatItMeans': d.whatItMeans,
    'keyNumbers': s.keyNumbers.map((k) => k.toMap()).toList(),
    'faq': s.faq.map((f) => f.toMap()).toList(),
    if (s.scam != null) 'scam': s.scam!.toMap(),
    'sources': s.sources.map((x) => {'name': x.name, 'url': x.url, 'title': x.title}).toList(),
  };
}

/// Answers "Ask your own question": the configured endpoint ([kAskEndpoint])
/// when set, otherwise (or when it fails) the on-device answer.
class StoryAskService {
  final String endpoint;
  final http.Client? client;
  final Duration timeout;
  const StoryAskService({this.endpoint = kAskEndpoint, this.client, this.timeout = const Duration(seconds: 15)});

  Future<AskAnswer> ask(Story s, String question) async {
    var q = question.trim();
    if (q.length > kAskMaxChars) q = q.substring(0, kAskMaxChars);
    if (q.isEmpty) return const AskAnswer(kAskNoAnswer, AskSource.none);
    if (endpoint.isEmpty) return answerLocally(s, q);
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'slug': s.slug, 'question': q, 'story': askContext(s)}))
          .timeout(timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final a = body is Map ? (body['answer'] ?? '').toString().trim() : '';
        if (a.isNotEmpty) return AskAnswer(a, a == kAskNoAnswer ? AskSource.none : AskSource.remote);
      }
    } catch (_) {
      // Network / timeout / bad JSON: answer from the story instead.
    } finally {
      if (client == null) c.close();
    }
    return answerLocally(s, q);
  }
}
