import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String summary;
  final String simpleExplanation;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String? imageUrl;
  final DateTime publishedAt;
  final List<String> keyPoints;
  final bool isBreaking;
  final String whatHappened;
  final String whyItMatters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool aiProcessed;
  final String? aiModel;
  final String? aiPromptVersion;
  final DateTime? aiProcessedAt;

  /// 'IN' for India-focused stories, 'GLOBAL' otherwise.
  final String region;

  /// Optional translations of [simpleExplanation], keyed by language code
  /// (`te`, `ta`, `hi`).
  final Map<String, String> simpleExplanationTranslations;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.simpleExplanation,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl,
    required this.publishedAt,
    required this.keyPoints,
    this.isBreaking = false,
    this.whatHappened = '',
    this.whyItMatters = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.aiProcessed = false,
    this.aiModel,
    this.aiPromptVersion,
    this.aiProcessedAt,
    this.region = 'GLOBAL',
    this.simpleExplanationTranslations = const {},
  })  : createdAt = createdAt ?? publishedAt,
        updatedAt = updatedAt ?? publishedAt;

  /// Estimated reading time in minutes based on article word count.
  int get readingTimeMinutes {
    final fullText = '$title $summary $simpleExplanation $whatHappened $whyItMatters ${keyPoints.join(' ')}';
    final words = fullText.trim().split(RegExp(r'\s+')).length;
    final minutes = (words / 180).ceil();
    return minutes < 1 ? 1 : (minutes > 15 ? 15 : minutes);
  }

  bool get isIndia => region.toUpperCase() == 'IN';

  /// Host of [sourceUrl] without `www.` (e.g. `blog.google`), or '' if invalid.
  String get sourceDomain {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null || uri.host.isEmpty) return '';
    final host = uri.host.toLowerCase();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static Map<String, String> _parseTranslations(dynamic value) {
    if (value is! Map) return const {};
    final out = <String, String>{};
    value.forEach((k, v) {
      if (k is String && v is String && v.trim().isNotEmpty) {
        out[k] = v.trim();
      }
    });
    return out;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'simpleExplanation': simpleExplanation,
      'category': category,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'keyPoints': keyPoints,
      'isBreaking': isBreaking,
      'whatHappened': whatHappened,
      'whyItMatters': whyItMatters,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'aiProcessed': aiProcessed,
      'aiModel': aiModel,
      'aiPromptVersion': aiPromptVersion,
      'aiProcessedAt': aiProcessedAt != null ? Timestamp.fromDate(aiProcessedAt!) : null,
      'region': region,
      if (simpleExplanationTranslations.isNotEmpty)
        'simpleExplanationTranslations': simpleExplanationTranslations,
    };
  }

  factory Article.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Article(
      id: (map['id'] as String?)?.isNotEmpty == true
          ? map['id'] as String
          : (docId ?? ''),
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      simpleExplanation: map['simpleExplanation'] as String? ?? '',
      category: map['category'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      publishedAt: _parseDateTime(map['publishedAt']),
      keyPoints: (map['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isBreaking: map['isBreaking'] as bool? ?? false,
      whatHappened: map['whatHappened'] as String? ?? '',
      whyItMatters: map['whyItMatters'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt'] ?? map['publishedAt']),
      updatedAt: _parseDateTime(map['updatedAt'] ?? map['publishedAt']),
      aiProcessed: map['aiProcessed'] as bool? ?? false,
      aiModel: map['aiModel'] as String?,
      aiPromptVersion: map['aiPromptVersion'] as String?,
      aiProcessedAt: map['aiProcessedAt'] != null ? _parseDateTime(map['aiProcessedAt']) : null,
      region: (map['region'] as String?)?.trim().isNotEmpty == true
          ? (map['region'] as String).trim().toUpperCase()
          : 'GLOBAL',
      simpleExplanationTranslations:
          _parseTranslations(map['simpleExplanationTranslations']),
    );
  }

  Article copyWith({
    String? id,
    String? title,
    String? summary,
    String? simpleExplanation,
    String? category,
    String? sourceName,
    String? sourceUrl,
    String? imageUrl,
    DateTime? publishedAt,
    List<String>? keyPoints,
    bool? isBreaking,
    String? whatHappened,
    String? whyItMatters,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? aiProcessed,
    String? aiModel,
    String? aiPromptVersion,
    DateTime? aiProcessedAt,
    String? region,
    Map<String, String>? simpleExplanationTranslations,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      simpleExplanation: simpleExplanation ?? this.simpleExplanation,
      category: category ?? this.category,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      keyPoints: keyPoints ?? this.keyPoints,
      isBreaking: isBreaking ?? this.isBreaking,
      whatHappened: whatHappened ?? this.whatHappened,
      whyItMatters: whyItMatters ?? this.whyItMatters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aiProcessed: aiProcessed ?? this.aiProcessed,
      aiModel: aiModel ?? this.aiModel,
      aiPromptVersion: aiPromptVersion ?? this.aiPromptVersion,
      aiProcessedAt: aiProcessedAt ?? this.aiProcessedAt,
      region: region ?? this.region,
      simpleExplanationTranslations:
          simpleExplanationTranslations ?? this.simpleExplanationTranslations,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
