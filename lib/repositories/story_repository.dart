// ignore_for_file: prefer_initializing_formals (private fields cannot be named parameters)
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/story.dart';

/// Where the app gets stories from.
abstract class StoryRepository {
  /// Latest stories + "Today in 5". Cached in memory; [refresh] forces a reload.
  Future<StoryFeed> loadFeed({bool refresh = false});

  /// A single story by its URL slug (falls back to the database for older stories).
  Future<Story?> getBySlug(String slug);

  /// The story from the already-loaded feed, without waiting (null if the
  /// feed is not loaded yet or the story is not in it).
  Story? cachedBySlug(String slug) => null;

  /// Stories matching [query] (client-side over the loaded feed).
  Future<List<Story>> search(String query) async {
    final feed = await loadFeed();
    return feed.stories.where((s) => s.matches(query)).toList();
  }
}

/// Production repository.
///
/// 1. Reads the pre-rendered `/data/feed.json` that the hourly GitHub Actions
///    run publishes to Hosting — no Firestore reads per visitor, which keeps
///    the free Spark plan's 50k reads/day for the backend.
/// 2. Falls back to Firestore (`stories` + `storyBriefs/latest`) when the
///    file is missing (local dev, first deploy).
class HostedStoryRepository extends StoryRepository {
  final http.Client _http;
  final FirebaseFirestore? _firestore;
  final Uri feedUri;
  StoryFeed? _cache;
  Future<StoryFeed>? _inflight;

  HostedStoryRepository({http.Client? client, FirebaseFirestore? firestore, Uri? feedUri})
      : _http = client ?? http.Client(),
        _firestore = firestore,
        feedUri = feedUri ?? defaultFeedUri();

  static Uri defaultFeedUri() =>
      kIsWeb ? Uri.base.resolve('/data/feed.json') : Uri.parse('$kSiteUrl/data/feed.json');

  @override
  Future<StoryFeed> loadFeed({bool refresh = false}) {
    if (!refresh && _cache != null) return Future.value(_cache);
    if (!refresh && _inflight != null) return _inflight!;
    final f = _load().then((feed) {
      _cache = feed;
      return feed;
    }).whenComplete(() => _inflight = null);
    _inflight = f;
    return f;
  }

  Future<StoryFeed> _load() async {
    try {
      final uri = feedUri.replace(queryParameters: {'t': (DateTime.now().millisecondsSinceEpoch ~/ 300000).toString()});
      final res = await _http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.body.trimLeft().startsWith('{')) {
        // ~430 KB of JSON: parsed on a background isolate on Android so the
        // UI thread never stalls (web has no isolates; compute runs inline).
        final feed = kIsWeb ? parseFeedBytes(res.bodyBytes) : await compute(parseFeedBytes, res.bodyBytes);
        if (feed.stories.isNotEmpty) return feed;
      }
    } catch (e) {
      debugPrint('feed.json unavailable, using Firestore: $e');
    }
    return _loadFromFirestore();
  }

  Future<StoryFeed> _loadFromFirestore() async {
    final db = _firestore;
    if (db == null) return _cache ?? StoryFeed.empty;
    final snap = await db.collection('stories').orderBy('publishedAt', descending: true).limit(150).get();
    final stories = snap.docs.map((d) => Story.fromMap(d.data(), docId: d.id)).where((s) => s.isValid).toList();
    var today = <TodayItem>[];
    try {
      final b = await db.collection('storyBriefs').doc('latest').get();
      final items = b.data()?['items'];
      if (items is List) {
        today = items.whereType<Map>().map((e) => TodayItem.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    return StoryFeed(stories: stories, today: today);
  }

  @override
  Story? cachedBySlug(String slug) => _cache?.bySlug(slug);

  @override
  Future<Story?> getBySlug(String slug) async {
    final feed = await loadFeed();
    final hit = feed.bySlug(slug);
    if (hit != null) return hit;
    final db = _firestore;
    if (db == null) return null;
    final snap = await db.collection('stories').where('slug', isEqualTo: slug).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Story.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
  }
}

/// Decodes `/data/feed.json` bytes (top-level so `compute` can run it).
StoryFeed parseFeedBytes(Uint8List bytes) => StoryFeed.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

/// Fixed in-memory stories (tests, `TECHDAILY_DATA_SOURCE=local` demos).
class InMemoryStoryRepository extends StoryRepository {
  final StoryFeed feed;
  int loads = 0;
  InMemoryStoryRepository(this.feed);

  @override
  Future<StoryFeed> loadFeed({bool refresh = false}) async {
    loads++;
    return feed;
  }

  @override
  Story? cachedBySlug(String slug) => feed.bySlug(slug);

  @override
  Future<Story?> getBySlug(String slug) async => feed.bySlug(slug);
}
