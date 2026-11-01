import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  final List<String> selectedCategories;
  final bool breakingNewsNotifications;
  final bool dailyBriefNotifications;
  final bool aiNewsNotifications;
  final bool securityNewsNotifications;
  final DateTime updatedAt;

  const UserPreferences({
    this.selectedCategories = const [],
    this.breakingNewsNotifications = true,
    this.dailyBriefNotifications = true,
    this.aiNewsNotifications = false,
    this.securityNewsNotifications = false,
    required this.updatedAt,
  });

  factory UserPreferences.defaultPreferences() {
    return UserPreferences(
      selectedCategories: const [],
      breakingNewsNotifications: true,
      dailyBriefNotifications: true,
      aiNewsNotifications: false,
      securityNewsNotifications: false,
      updatedAt: DateTime.now(),
    );
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
      'selectedCategories': selectedCategories,
      'breakingNewsNotifications': breakingNewsNotifications,
      'dailyBriefNotifications': dailyBriefNotifications,
      'aiNewsNotifications': aiNewsNotifications,
      'securityNewsNotifications': securityNewsNotifications,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    final rawCats = map['selectedCategories'] as List<dynamic>? ?? [];
    return UserPreferences(
      selectedCategories: rawCats.map((c) => c.toString()).toList(),
      breakingNewsNotifications: map['breakingNewsNotifications'] as bool? ?? true,
      dailyBriefNotifications: map['dailyBriefNotifications'] as bool? ?? true,
      aiNewsNotifications: map['aiNewsNotifications'] as bool? ?? false,
      securityNewsNotifications: map['securityNewsNotifications'] as bool? ?? false,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  UserPreferences copyWith({
    List<String>? selectedCategories,
    bool? breakingNewsNotifications,
    bool? dailyBriefNotifications,
    bool? aiNewsNotifications,
    bool? securityNewsNotifications,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      breakingNewsNotifications:
          breakingNewsNotifications ?? this.breakingNewsNotifications,
      dailyBriefNotifications:
          dailyBriefNotifications ?? this.dailyBriefNotifications,
      aiNewsNotifications: aiNewsNotifications ?? this.aiNewsNotifications,
      securityNewsNotifications:
          securityNewsNotifications ?? this.securityNewsNotifications,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  bool isCategorySelected(String category) {
    if (selectedCategories.isEmpty) return true; // Default: show all if none specifically chosen
    return selectedCategories.any((c) => c.toLowerCase() == category.toLowerCase());
  }
}
