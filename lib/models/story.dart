import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../core/config/app_config.dart';
import '../core/constants/story_categories.dart';
import '../core/constants/story_questions.dart';

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (v is Map && v['_seconds'] is num) {
    return DateTime.fromMillisecondsSinceEpoch(((v['_seconds'] as num) * 1000).round());
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<String> _strings(dynamic v) =>
    v is List ? v.whereType<Object>().map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : const [];

class StorySource {
  final String name;
  final String url;
  final String title;
  final DateTime publishedAt;

  const StorySource({required this.name, required this.url, this.title = '', required this.publishedAt});

  factory StorySource.fromMap(Map<String, dynamic> m) => StorySource(
        name: (m['name'] ?? '').toString(),
        url: (m['url'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        publishedAt: _date(m['publishedAt']),
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'url': url, 'title': title, 'publishedAt': publishedAt.toUtc().toIso8601String()};
}

class ScamInfo {
  final String howItWorks;
  final List<String> warningSigns;
  final List<String> ifTargeted;
  final String? advisoryUrl;

  const ScamInfo({
    required this.howItWorks,
    required this.warningSigns,
    required this.ifTargeted,
    this.advisoryUrl,
  });

  static ScamInfo? fromMap(dynamic m) {
    if (m is! Map) return null;
    final how = (m['howItWorks'] ?? '').toString();
    if (how.isEmpty) return null;
    final adv = m['advisoryUrl'];
    return ScamInfo(
      howItWorks: how,
      warningSigns: _strings(m['warningSigns']),
      ifTargeted: _strings(m['ifTargeted']),
      advisoryUrl: adv is String && adv.startsWith('http') ? adv : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'howItWorks': howItWorks,
        'warningSigns': warningSigns,
        'ifTargeted': ifTargeted,
        'advisoryUrl': advisoryUrl,
      };
}

/// "Key numbers" chip: a number that appears in the reports.
class KeyNumber {
  final String value;
  final String label;
  const KeyNumber(this.value, this.label);

  static List<KeyNumber> listFrom(dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((m) => KeyNumber((m['value'] ?? '').toString(), (m['label'] ?? '').toString()))
          .where((k) => k.value.isNotEmpty && k.label.isNotEmpty)
          .take(4)
          .toList()
      : const [];

  Map<String, dynamic> toMap() => {'value': value, 'label': label};
}

/// One "Ask about this" question with a short answer.
class FaqItem {
  final String q;
  final String a;
  const FaqItem(this.q, this.a);

  static List<FaqItem> listFrom(dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((m) => FaqItem((m['q'] ?? '').toString(), (m['a'] ?? '').toString()))
          .where((f) => f.q.isNotEmpty && f.a.isNotEmpty)
          .take(4)
          .toList()
      : const [];

  Map<String, dynamic> toMap() => {'q': q, 'a': a};
}

/// The publisher's lead image: hotlinked (never copied) and always shown
/// with a visible "Image: sourceName" credit linking to [sourceUrl].
class StoryImage {
  final String url;
  final String sourceName;
  final String sourceUrl;
  final int? width;
  final int? height;

  const StoryImage({required this.url, required this.sourceName, required this.sourceUrl, this.width, this.height});

  /// Only https images with a credit are accepted (mixed content / unsafe
  /// links are dropped and the category art is shown instead).
  static StoryImage? fromMap(dynamic m) {
    if (m is! Map) return null;
    final url = (m['url'] ?? '').toString();
    final sourceUrl = (m['sourceUrl'] ?? '').toString();
    final sourceName = (m['sourceName'] ?? '').toString();
    final u = Uri.tryParse(url);
    final su = Uri.tryParse(sourceUrl);
    if (u == null || u.scheme != 'https' || u.host.isEmpty) return null;
    if (su == null || !(su.scheme == 'https' || su.scheme == 'http') || sourceName.isEmpty) return null;
    int? n(dynamic v) => v is num && v > 0 ? v.toInt() : null;
    return StoryImage(url: url, sourceName: sourceName, sourceUrl: sourceUrl, width: n(m['width']), height: n(m['height']));
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

/// One news event in simple words, backed by one or more original reports.
class Story {
  final String id;
  final String slug;
  final String headline;
  final String category;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final List<StorySource> sources;
  final String tldr;
  final List<KeyNumber> keyNumbers;
  final String whatHappened;
  final String affectsWho;
  final List<String> whatToDo;
  final String goodToKnow;
  final String whatItMeans;
  final List<FaqItem> faq;
  final ScamInfo? scam;
  final String confidence;
  final bool developing;
  final String aiModel;
  final String region;
  final StoryImage? image;
  final String promptVersion;

  /// The English story this one was translated from (null for originals).
  /// Navigation, saving and re-translation always use the original.
  final Story? translatedFrom;

  /// The English original of this story.
  Story get original => translatedFrom ?? this;

  const Story({
    required this.id,
    required this.slug,
    required this.headline,
    required this.category,
    required this.publishedAt,
    required this.updatedAt,
    required this.sources,
    required this.whatHappened,
    required this.affectsWho,
    required this.whatToDo,
    required this.whatItMeans,
    this.tldr = '',
    this.keyNumbers = const [],
    this.goodToKnow = '',
    this.faq = const [],
    this.promptVersion = '',
    this.scam,
    this.confidence = 'medium',
    this.developing = false,
    this.aiModel = '',
    this.region = 'GLOBAL',
    this.image,
    this.translatedFrom,
  });

  factory Story.fromMap(Map<String, dynamic> m, {String? docId}) {
    final sources = (m['sources'] is List ? m['sources'] as List : const [])
        .whereType<Map>()
        .map((e) => StorySource.fromMap(Map<String, dynamic>.from(e)))
        .where((s) => s.url.startsWith('http'))
        .toList();
    final cat = (m['category'] ?? '').toString();
    return Story(
      id: (m['id'] ?? docId ?? '').toString(),
      slug: (m['slug'] ?? '').toString(),
      headline: (m['headline'] ?? '').toString(),
      category: isStoryCategoryId(cat) ? cat : 'innovations',
      publishedAt: _date(m['publishedAt']),
      updatedAt: _date(m['updatedAt'] ?? m['publishedAt']),
      sources: sources,
      whatHappened: (m['whatHappened'] ?? '').toString(),
      affectsWho: (m['affectsWho'] ?? '').toString(),
      whatToDo: _strings(m['whatToDo']),
      whatItMeans: (m['whatItMeans'] ?? '').toString(),
      tldr: (m['tldr'] ?? '').toString(),
      keyNumbers: KeyNumber.listFrom(m['keyNumbers']),
      goodToKnow: (m['goodToKnow'] ?? '').toString(),
      faq: FaqItem.listFrom(m['faq']),
      promptVersion: (m['promptVersion'] ?? '').toString(),
      scam: ScamInfo.fromMap(m['scam']),
      confidence: (m['confidence'] ?? 'medium').toString(),
      developing: m['developing'] == true,
      aiModel: (m['aiModel'] ?? '').toString(),
      region: m['region'] == 'IN' ? 'IN' : 'GLOBAL',
      image: StoryImage.fromMap(m['image']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slug': slug,
        'headline': headline,
        'category': category,
        'publishedAt': publishedAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'sources': sources.map((s) => s.toMap()).toList(),
        'whatHappened': whatHappened,
        'affectsWho': affectsWho,
        'whatToDo': whatToDo,
        'whatItMeans': whatItMeans,
        'tldr': tldr,
        'keyNumbers': keyNumbers.map((k) => k.toMap()).toList(),
        'goodToKnow': goodToKnow,
        'faq': faq.map((f) => f.toMap()).toList(),
        'promptVersion': promptVersion,
        'scam': scam?.toMap(),
        'confidence': confidence,
        'developing': developing,
        'aiModel': aiModel,
        'region': region,
        'image': image?.toMap(),
      };

  bool get isValid => id.isNotEmpty && slug.isNotEmpty && headline.isNotEmpty;

  /// A copy with translated text (Telugu / Hindi from the AI Worker). Field
  /// names match `StoryTranslator.fullFields`; anything missing, or a list of
  /// the wrong length, keeps the original English.
  Story withTranslation(Map<String, Object> f) {
    String s(String k, String orig) {
      final v = f[k];
      return v is String && v.trim().isNotEmpty ? v : orig;
    }

    List<String> l(String k, List<String> orig) {
      final v = f[k];
      return v is List<String> && v.length == orig.length && orig.isNotEmpty ? v : orig;
    }

    // whatToDo / tldr etc. were sent after StoryDisplay cleaned them; when the
    // cleaned list differs from the stored one, translate the cleaned list.
    final shownTodo = display.whatToDo;
    final todo = f['whatToDo'] is List<String> && (f['whatToDo'] as List<String>).length == shownTodo.length ? f['whatToDo'] as List<String> : whatToDo;
    final labels = l('keyLabels', keyNumbers.map((k) => k.label).toList());
    final qs = l('faqQ', faq.map((x) => x.q).toList());
    final as = l('faqA', faq.map((x) => x.a).toList());
    return Story(
      id: id,
      slug: slug,
      headline: s('headline', headline),
      category: category,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      sources: sources,
      whatHappened: s('whatHappened', whatHappened),
      affectsWho: s('affectsWho', affectsWho),
      whatToDo: todo,
      whatItMeans: s('whatItMeans', whatItMeans),
      tldr: s('tldr', tldr),
      keyNumbers: [for (var i = 0; i < keyNumbers.length; i++) KeyNumber(keyNumbers[i].value, labels[i])],
      goodToKnow: s('goodToKnow', goodToKnow),
      faq: [for (var i = 0; i < faq.length; i++) FaqItem(qs[i], as[i])],
      promptVersion: promptVersion,
      scam: scam == null
          ? null
          : ScamInfo(
              howItWorks: s('scamHow', scam!.howItWorks),
              warningSigns: l('scamSigns', scam!.warningSigns),
              ifTargeted: l('scamIfTargeted', scam!.ifTargeted),
              advisoryUrl: scam!.advisoryUrl,
            ),
      confidence: confidence,
      developing: developing,
      aiModel: aiModel,
      region: region,
      image: image,
      translatedFrom: original,
    );
  }

  StoryCategory get categoryInfo => storyCategoryById(category);

  /// Distinct publisher names, in order.
  List<String> get sourceNames {
    final seen = <String>{};
    return [for (final s in sources) if (s.name.isNotEmpty && seen.add(s.name)) s.name];
  }

  /// Public URL of the pre-rendered story page.
  String get webUrl => '$kSiteUrl/story/${Uri.encodeComponent(slug)}/';

  bool get isFallback => aiModel.startsWith('techdaily-fallback');

  bool get isScam => scam != null;

  /// Per-category questions for this story (scam stories use the scam set).
  StoryQuestionSet get questions => questionsFor(category, isScam: isScam);

  /// Text actually shown (legacy boilerplate stripped).
  StoryDisplay get display => StoryDisplay.of(
        aiModel: aiModel,
        promptVersion: promptVersion,
        tldr: tldr,
        whatHappened: whatHappened,
        affectsWho: affectsWho,
        whatToDo: whatToDo,
        goodToKnow: goodToKnow,
        whatItMeans: whatItMeans,
      );

  /// Same formula as the backend ranking (recency x coverage x confidence).
  double score(DateTime now) {
    final ageH = math.max(0, now.difference(publishedAt).inMinutes / 60.0);
    final recency = math.pow(0.5, ageH / 12).toDouble();
    final coverage = 1 + 0.6 * math.min(sourceNames.length - 1, 4);
    final conf = confidence == 'high' ? 1.15 : (confidence == 'low' ? 0.8 : 1.0);
    final local = region == 'IN' ? 1.15 : 1.0;
    final act = category == 'scams-security' && scam != null ? 1.2 : 1.0;
    return recency * coverage * conf * local * act;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    final hay = [
      headline,
      tldr,
      whatHappened,
      affectsWho,
      whatItMeans,
      categoryInfo.label,
      ...sourceNames,
      ...whatToDo,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }
}

class TodayItem {
  final String storyId;
  final String slug;
  final String headline;
  final String category;
  final String whatItMeans;

  const TodayItem({
    required this.storyId,
    required this.slug,
    required this.headline,
    required this.category,
    this.whatItMeans = '',
  });

  factory TodayItem.fromMap(Map<String, dynamic> m) => TodayItem(
        storyId: (m['storyId'] ?? '').toString(),
        slug: (m['slug'] ?? '').toString(),
        headline: (m['headline'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        whatItMeans: (m['whatItMeans'] ?? '').toString(),
      );

  factory TodayItem.fromStory(Story s) =>
      TodayItem(storyId: s.id, slug: s.slug, headline: s.headline, category: s.category, whatItMeans: s.whatItMeans);
}

/// Everything the home screen needs, loaded in one go.
class StoryFeed {
  final List<Story> stories;
  final List<TodayItem> today;
  final List<String> topIds;
  final DateTime? generatedAt;

  const StoryFeed({required this.stories, required this.today, this.topIds = const [], this.generatedAt});

  static const empty = StoryFeed(stories: [], today: []);

  factory StoryFeed.fromJson(Map<String, dynamic> m) {
    final stories = (m['stories'] is List ? m['stories'] as List : const [])
        .whereType<Map>()
        .map((e) => Story.fromMap(Map<String, dynamic>.from(e)))
        .where((s) => s.isValid)
        .toList();
    final todayMap = m['today'] is Map ? Map<String, dynamic>.from(m['today'] as Map) : const <String, dynamic>{};
    final items = (todayMap['items'] is List ? todayMap['items'] as List : const [])
        .whereType<Map>()
        .map((e) => TodayItem.fromMap(Map<String, dynamic>.from(e)))
        .where((t) => t.slug.isNotEmpty)
        .toList();
    return StoryFeed(
      stories: stories,
      today: items,
      topIds: _strings(m['top']),
      generatedAt: m['generatedAt'] == null ? null : _date(m['generatedAt']),
    );
  }

  /// Ranked mix for the "Top Stories" tab.
  List<Story> topStories({DateTime? now}) {
    if (topIds.isNotEmpty) {
      final byId = {for (final s in stories) s.id: s};
      final ranked = [for (final id in topIds) if (byId[id] != null) byId[id]!];
      final rest = stories.where((s) => !topIds.contains(s.id));
      return [...ranked, ...rest];
    }
    final n = now ?? DateTime.now();
    final list = [...stories]..sort((a, b) => b.score(n).compareTo(a.score(n)));
    return list;
  }

  List<Story> inCategory(String id) => stories.where((s) => s.category == id).toList();

  Story? bySlug(String slug) {
    for (final s in stories) {
      if (s.slug == slug) return s;
    }
    return null;
  }

  Story? byId(String id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }
}
