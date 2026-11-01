import 'package:cloud_firestore/cloud_firestore.dart';

class DailyBriefItem {
  final int rank;
  final String articleId;
  final String headline;
  final String whyItMatters;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String whatHappened;
  final List<String> keyPoints;

  const DailyBriefItem({
    required this.rank,
    required this.articleId,
    required this.headline,
    required this.whyItMatters,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.whatHappened = '',
    this.keyPoints = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'articleId': articleId,
      'headline': headline,
      'whyItMatters': whyItMatters,
      'category': category,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'whatHappened': whatHappened,
      'keyPoints': keyPoints,
    };
  }

  factory DailyBriefItem.fromMap(Map<String, dynamic> map) {
    return DailyBriefItem(
      rank: map['rank'] as int? ?? 1,
      articleId: map['articleId'] as String? ?? '',
      headline: map['headline'] as String? ?? '',
      whyItMatters: map['whyItMatters'] as String? ?? '',
      category: map['category'] as String? ?? 'Technology',
      sourceName: map['sourceName'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      whatHappened: map['whatHappened'] as String? ?? '',
      keyPoints: (map['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class DailyBrief {
  final String id;
  final DateTime date;
  final String title;
  final String subtitle;
  final List<DailyBriefItem> items;
  final DateTime createdAt;

  const DailyBrief({
    required this.id,
    required this.date,
    this.title = 'TODAY IN TECH',
    this.subtitle = '10 essential technology developments curated from verified primary wires.',
    required this.items,
    required this.createdAt,
  });

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
      'date': Timestamp.fromDate(date),
      'title': title,
      'subtitle': subtitle,
      'items': items.map((i) => i.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DailyBrief.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return DailyBrief(
      id: (map['id'] as String?)?.isNotEmpty == true
          ? map['id'] as String
          : (docId ?? ''),
      date: _parseDateTime(map['date']),
      title: map['title'] as String? ?? 'TODAY IN TECH',
      subtitle: map['subtitle'] as String? ??
          '10 essential technology developments curated from verified primary wires.',
      items: rawItems
          .map((item) => DailyBriefItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: _parseDateTime(map['createdAt'] ?? map['date']),
    );
  }
}
