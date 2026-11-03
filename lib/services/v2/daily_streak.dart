import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scam_game.dart' show istDateKey;

/// "You're all caught up" streak: days in a row the reader finished Today in 5.
class CaughtUpStreak extends ChangeNotifier {
  static const _kLast = 'today5.last';
  static const _kStreak = 'today5.streak';
  final DateTime Function() clock;
  CaughtUpStreak({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  int streak = 0;
  String last = '';

  bool get doneToday => last == istDateKey(clock());

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      last = p.getString(_kLast) ?? '';
      streak = p.getInt(_kStreak) ?? 0;
      final today = istDateKey(clock());
      final yesterday = istDateKey(clock().subtract(const Duration(days: 1)));
      if (last.isNotEmpty && last != today && last != yesterday) streak = 0;
    } catch (_) {}
    notifyListeners();
  }

  /// Marks today's Today in 5 as finished; returns the new streak.
  Future<int> markDone() async {
    final today = istDateKey(clock());
    if (last != today) {
      final yesterday = istDateKey(clock().subtract(const Duration(days: 1)));
      streak = last == yesterday ? streak + 1 : 1;
      last = today;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kLast, last);
        await p.setInt(_kStreak, streak);
      } catch (_) {}
      notifyListeners();
    }
    return streak;
  }
}
