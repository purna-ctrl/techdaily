import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Device-local bookmarks for signed-out readers. Merged into the user's
/// Firestore bookmarks the next time they sign in.
class GuestBookmarkStore {
  const GuestBookmarkStore();

  Future<Set<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(AppConstants.savedArticleIdsKey) ?? const <String>[])
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> save(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(AppConstants.savedArticleIdsKey, ids.toList());
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.savedArticleIdsKey);
    } catch (_) {}
  }
}
