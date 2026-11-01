class ReadingHistoryItem {
  final String articleId;
  final String title;
  final String category;
  final String sourceName;
  final DateTime readAt;
  final int readingTimeMinutes;

  ReadingHistoryItem({
    required this.articleId,
    required this.title,
    required this.category,
    required this.sourceName,
    required this.readAt,
    this.readingTimeMinutes = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'articleId': articleId,
      'title': title,
      'category': category,
      'sourceName': sourceName,
      'readAt': readAt.toIso8601String(),
      'readingTimeMinutes': readingTimeMinutes,
    };
  }

  factory ReadingHistoryItem.fromMap(Map<String, dynamic> map) {
    return ReadingHistoryItem(
      articleId: map['articleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      readAt: DateTime.tryParse(map['readAt']?.toString() ?? '') ?? DateTime.now(),
      readingTimeMinutes: (map['readingTimeMinutes'] as num?)?.toInt() ?? 3,
    );
  }
}
