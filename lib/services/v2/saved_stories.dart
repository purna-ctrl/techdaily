import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/story.dart';

/// Server copy of a signed-in reader's saved stories.
abstract class SavedStoriesRemote {
  /// Saved stories, newest first.
  Stream<List<Story>> watch(String uid);
  Future<void> save(String uid, Story story);
  Future<void> remove(String uid, String storyId);
}

/// `users/{uid}/savedStories/{storyId}` = {storyId, savedAt, story: {...snapshot}}.
/// The snapshot keeps saved stories readable after they leave the live feed.
class FirestoreSavedStoriesRemote implements SavedStoriesRemote {
  final FirebaseFirestore _db;
  FirestoreSavedStoriesRemote([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('savedStories');

  @override
  Stream<List<Story>> watch(String uid) => _col(uid).orderBy('savedAt', descending: true).snapshots().map((s) => s.docs
      .map((d) {
        final m = d.data()['story'];
        return m is Map ? Story.fromMap(Map<String, dynamic>.from(m), docId: d.id) : null;
      })
      .whereType<Story>()
      .where((x) => x.isValid)
      .toList());

  @override
  Future<void> save(String uid, Story story) => _col(uid).doc(story.id).set({
        'storyId': story.id,
        'savedAt': FieldValue.serverTimestamp(),
        'story': story.toMap(),
      });

  @override
  Future<void> remove(String uid, String storyId) => _col(uid).doc(storyId).delete();
}

/// Saved stories for guests (on this device) and signed-in readers (Firestore).
/// When a guest signs in, their device saves are merged into the account.
class SavedStoriesController extends ChangeNotifier {
  static const prefsKey = 'techdaily_saved_stories_v2';

  final SavedStoriesRemote? remote;
  final List<Story> _stories = [];
  String? _uid;
  StreamSubscription<List<Story>>? _sub;
  bool _loaded = false;

  SavedStoriesController({this.remote});

  bool get isGuest => (_uid ?? '').isEmpty;
  bool get loaded => _loaded;
  List<Story> get stories => List.unmodifiable(_stories);
  bool isSaved(String storyId) => _stories.any((s) => s.id == storyId);

  Future<List<Story>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => Story.fromMap(Map<String, dynamic>.from(m)))
          .where((s) => s.isValid)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocal(List<Story> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(list.map((s) => s.toMap()).toList()));
    } catch (_) {}
  }

  /// Switches between the guest list and [uid]'s account (merging guest saves in).
  Future<void> bind(String? uid) async {
    if (_loaded && _uid == uid) return;
    _uid = uid;
    await _sub?.cancel();
    _sub = null;
    final local = await _readLocal();
    if (uid == null || uid.isEmpty || remote == null) {
      _stories
        ..clear()
        ..addAll(local);
      _loaded = true;
      notifyListeners();
      return;
    }
    if (local.isNotEmpty) {
      try {
        for (final s in local) {
          await remote!.save(uid, s);
        }
        await _writeLocal(const []);
      } catch (e) {
        debugPrint('Saved-story merge failed (kept on device): $e');
      }
    }
    _stories
      ..clear()
      ..addAll(local);
    _loaded = true;
    notifyListeners();
    _sub = remote!.watch(uid).listen((list) {
      _stories
        ..clear()
        ..addAll(list);
      notifyListeners();
    }, onError: (Object e) => debugPrint('Saved stories stream error: $e'));
  }

  /// Saves or un-saves [story]. Returns the new saved state.
  Future<bool> toggle(Story story) async {
    final wasSaved = isSaved(story.id);
    if (wasSaved) {
      _stories.removeWhere((s) => s.id == story.id);
    } else {
      _stories.insert(0, story);
    }
    notifyListeners();
    final uid = _uid;
    try {
      if (uid == null || uid.isEmpty || remote == null) {
        await _writeLocal(_stories);
      } else if (wasSaved) {
        await remote!.remove(uid, story.id);
      } else {
        await remote!.save(uid, story);
      }
    } catch (e) {
      debugPrint('Saving story failed: $e');
    }
    return !wasSaved;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
