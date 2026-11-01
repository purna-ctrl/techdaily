import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/story_categories.dart';

/// Which category tabs the reader has hidden (Settings → Topics). Stored on
/// this device only. "Top Stories" also leaves out hidden categories.
class TopicPrefs extends ValueNotifier<Set<String>> {
  static const prefsKey = 'techdaily_hidden_categories';

  TopicPrefs() : super(<String>{});

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = (prefs.getStringList(prefsKey) ?? const <String>[]).where(isStoryCategoryId).toSet();
    } catch (_) {}
  }

  bool isVisible(String categoryId) => !value.contains(categoryId);

  List<StoryCategory> get visibleCategories => kStoryCategories.where((c) => isVisible(c.id)).toList();

  Future<void> setVisible(String categoryId, bool visible) async {
    final next = {...value};
    if (visible) {
      next.remove(categoryId);
    } else {
      // Keep at least one category visible.
      if (kStoryCategories.length - next.length <= 1) return;
      next.add(categoryId);
    }
    value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, next.toList());
    } catch (_) {}
  }

  Future<void> showAll() async {
    value = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (_) {}
  }
}
