import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techdaily/core/constants/story_categories.dart';
import 'package:techdaily/core/stories_scope.dart';
import 'package:techdaily/models/story.dart';
import 'package:techdaily/services/v2/newsletter_service.dart';
import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/saved_stories.dart';
import 'package:techdaily/services/v2/story_share.dart';
import 'package:techdaily/services/v2/topic_prefs.dart';

class _FakeRemote implements SavedStoriesRemote {
  final Map<String, Map<String, Story>> data = {};
  @override
  Future<void> remove(String uid, String storyId) async => data[uid]?.remove(storyId);
  @override
  Future<void> save(String uid, Story story) async => (data[uid] ??= {})[story.id] = story;
  @override
  Stream<List<Story>> watch(String uid) => Stream.value((data[uid] ?? {}).values.toList());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Story.fromMap parses feed.json shape incl. scam and ISO dates', () {
    final s = Story.fromMap({
      'id': 'st-1',
      'slug': 'a-b-123abc',
      'headline': 'H',
      'category': 'scams-security',
      'publishedAt': '2026-11-01T10:00:00.000Z',
      'updatedAt': '2026-11-01T11:00:00.000Z',
      'sources': [
        {'name': 'ET Tech', 'url': 'https://e.com/1', 'title': 't', 'publishedAt': '2026-11-01T10:00:00.000Z'},
        {'name': 'Bad', 'url': 'javascript:alert(1)'},
      ],
      'whatHappened': 'w',
      'affectsWho': 'a',
      'whatToDo': ['x', '', 'y'],
      'whatItMeans': 'm',
      'scam': {'howItWorks': 'h', 'warningSigns': ['s'], 'ifTargeted': ['t'], 'advisoryUrl': 'https://cert-in.org.in/x'},
      'confidence': 'low',
      'developing': true,
      'region': 'IN',
    });
    expect(s.sources, hasLength(1));
    expect(s.whatToDo, ['x', 'y']);
    expect(s.scam!.advisoryUrl, 'https://cert-in.org.in/x');
    expect(s.developing, isTrue);
    expect(s.webUrl, 'https://techdaily-prod.web.app/story/a-b-123abc/');
    expect(Story.fromMap(s.toMap()).toMap(), s.toMap());
    expect(Story.fromMap({'category': 'weird'}).category, 'innovations');
  });

  test('StoryFeed ranks Top Stories by top ids, then score; search matches all words', () {
    final feed = sampleStoryFeed(now: DateTime.utc(2026, 11, 1, 12));
    expect(feed.topStories().first.id, 'demo-scam-1');
    final withTop = StoryFeed(stories: feed.stories, today: const [], topIds: const ['demo-chip-1']);
    expect(withTop.topStories().first.id, 'demo-chip-1');
    expect(withTop.topStories(), hasLength(feed.stories.length));
    expect(feed.stories.where((s) => s.matches('upi record')).map((s) => s.id), ['demo-money-1']);
    expect(feed.bySlug('upi-sets-monthly-record-demo04')!.id, 'demo-money-1');
    final parsed = StoryFeed.fromJson({
      'stories': [feed.stories.first.toMap()],
      'today': {
        'items': [
          {'storyId': 'demo-scam-1', 'slug': feed.stories.first.slug, 'headline': 'h', 'category': 'scams-security'}
        ]
      },
      'top': ['demo-scam-1'],
      'generatedAt': '2026-11-01T12:00:00Z',
    });
    expect(parsed.today.single.slug, feed.stories.first.slug);
  });

  test('AppRoute parses app and static paths', () {
    expect(AppRoute.parse('/app/story/abc-1').kind, AppRouteKind.story);
    expect(AppRoute.parse('/story/abc-1/').param, 'abc-1');
    expect(AppRoute.parse('/app/c/ai').param, 'ai');
    expect(AppRoute.parse('/app/').kind, AppRouteKind.home);
    expect(AppRoute.parse('/').kind, AppRouteKind.home);
    expect(AppRoute.parse('/app/newsletter?email=a%40b.co').param, 'a@b.co');
    expect(AppRoute.parse('/article/x').kind, AppRouteKind.legacyArticle);
    expect(AppRoute.parse('/app/nope/x/y').kind, AppRouteKind.unknown);
    expect(storyRoutePath('a b'), '/app/story/a%20b');
  });

  test('WhatsApp share link = headline + story URL', () {
    final s = sampleStoryFeed().stories.first;
    final uri = StoryShare.whatsappUri(s);
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], '${s.headline}\n\n${s.webUrl}');
  });

  test('Email validation matches the Firestore rule', () {
    expect(isValidEmail('reader@example.com'), isTrue);
    expect(isValidEmail('a@b.c'), isFalse);
    expect(isValidEmail('no at sign'), isFalse);
    expect(isValidEmail('x y@z.com'), isFalse);
  });

  test('Topic prefs persist and keep at least one category visible', () async {
    SharedPreferences.setMockInitialValues({});
    final t = TopicPrefs();
    await t.setVisible('privacy', false);
    final again = TopicPrefs();
    await again.load();
    expect(again.value, {'privacy'});
    for (final c in kStoryCategories) {
      await again.setVisible(c.id, false);
    }
    expect(again.visibleCategories, hasLength(1));
    await again.showAll();
    expect(again.visibleCategories, hasLength(15));
  });

  test('Guest saves merge into the account on sign-in and clear the device copy', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemote();
    final c = SavedStoriesController(remote: remote);
    await c.bind(null);
    final s = sampleStoryFeed().stories.first;
    await c.toggle(s);
    expect(c.isGuest, isTrue);
    expect(c.isSaved(s.id), isTrue);
    await c.bind('uid-1');
    await Future<void>.delayed(Duration.zero);
    expect(remote.data['uid-1']!.keys, [s.id]);
    expect(c.isSaved(s.id), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SavedStoriesController.prefsKey), '[]');
    await c.toggle(s);
    expect(remote.data['uid-1'], isEmpty);
  });
}
