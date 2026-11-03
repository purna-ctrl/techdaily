import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techdaily/core/constants/jargon.dart';
import 'package:techdaily/core/constants/story_categories.dart';
import 'package:techdaily/models/story.dart';
import 'package:techdaily/services/v2/daily_streak.dart';
import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/scam_game.dart';
import 'package:techdaily/widgets/v3/category_art_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('StoryImage: https only, needs a credit; survives toMap/fromMap', () {
    final m = {
      'id': 'a',
      'slug': 'a-1',
      'headline': 'h',
      'category': 'ai',
      'sources': [],
      'image': {'url': 'https://cdn.x.com/a.jpg', 'sourceName': 'X', 'sourceUrl': 'https://x.com/a', 'width': 1200, 'height': 675},
    };
    final s = Story.fromMap(m);
    expect(s.image!.url, 'https://cdn.x.com/a.jpg');
    expect(s.image!.width, 1200);
    expect(Story.fromMap(s.toMap()).image!.sourceUrl, 'https://x.com/a');
    expect(StoryImage.fromMap({'url': 'http://cdn.x.com/a.jpg', 'sourceName': 'X', 'sourceUrl': 'https://x.com'}), isNull);
    expect(StoryImage.fromMap({'url': 'https://cdn.x.com/a.jpg', 'sourceName': '', 'sourceUrl': 'https://x.com'}), isNull);
    expect(StoryImage.fromMap({'url': 'https://cdn.x.com/a.jpg', 'sourceName': 'X', 'sourceUrl': 'javascript:alert(1)'}), isNull);
    expect(Story.fromMap({...m, 'image': null}).image, isNull);
  });

  test('every category (and Top Stories) has colour, tint and generated art', () {
    for (final c in [kTopStories, ...kStoryCategories]) {
      expect(kCategoryArt[c.id], isNotNull, reason: c.id);
      expect(kCategoryArt[c.id]!.prims, isNotEmpty);
      expect(c.color, isNot(c.tint));
    }
    expect(storyCategoryById('scams-security').color.toARGB32(), 0xFFFF3B4E);
    expect(storyCategoryById('ai').color.toARGB32(), 0xFF8B5CF6);
    expect(storyCategoryById('money-fintech').color.toARGB32(), 0xFFEAB308);
  });

  test('jargon: whole words, acronyms case-sensitive, no overlaps, ~40+ terms', () {
    expect(kJargon.length, greaterThanOrEqualTo(40));
    final hits = findJargon('Never share your UPI PIN or OTP. The LLM uses a chip; it is not IT.');
    final terms = hits.map((h) => h.$3.term).toList();
    expect(terms, containsAll(['UPI PIN', 'OTP', 'LLM', 'chip']));
    expect(terms, isNot(contains('UPI'))); // "UPI PIN" wins, no overlap
    expect(findJargon('This is it.'), isEmpty);
    expect(findJargon('chipset').map((h) => h.$3.term), ['processor']);
    expect(jargonIn(['Phishing via KYC', 'phishing again']).map((e) => e.term), ['phishing', 'KYC']);
  });

  test('Scam or Not: builds a realistic message from a scam story and a daily mixed round', () {
    final feed = sampleStoryFeed();
    final scam = feed.stories.firstWhere((s) => s.scam != null);
    final m = scamMessageFromStory(scam)!;
    expect(m.isScam, isTrue);
    expect(m.body, contains('parcel'));
    expect(m.signs, scam.scam!.warningSigns.take(3).toList());
    expect(m.storySlug, scam.slug);
    final day = DateTime.utc(2026, 11, 1, 6);
    final round = dailyScamRound(feed.stories, day);
    expect(round, hasLength(3));
    expect(round.where((x) => !x.isScam), hasLength(1));
    expect(round.any((x) => x.storySlug == scam.slug), isTrue);
    expect(dailyScamRound(feed.stories, day).map((x) => x.id), round.map((x) => x.id)); // stable for the day
    // Without news scams it falls back to the hand-written examples.
    final noNews = dailyScamRound(const [], day);
    expect(noNews.where((x) => x.isScam), hasLength(2));
    expect(kFallbackScams, hasLength(10));
  });

  test('Scam or Not: answers persist, streak grows on consecutive days and resets after a gap', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime.utc(2026, 11, 1, 6);
    final g = ScamGameController(clock: () => now);
    await g.load();
    var round = dailyScamRound(const [], now);
    for (final m in round) {
      await g.answer(m, saysScam: m.isScam, round: round);
    }
    expect(g.isDone(round), isTrue);
    expect(g.score(round), 3);
    expect(g.streak, 1);
    now = now.add(const Duration(days: 1));
    final g2 = ScamGameController(clock: () => now);
    await g2.load();
    round = dailyScamRound(const [], now);
    expect(g2.isDone(round), isFalse);
    for (final m in round) {
      await g2.answer(m, saysScam: true, round: round);
    }
    expect(g2.streak, 2);
    expect(g2.score(round), 2);
    now = now.add(const Duration(days: 3));
    final g3 = ScamGameController(clock: () => now);
    await g3.load();
    expect(g3.streak, 0);
  });

  test('Caught-up streak counts consecutive days', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime.utc(2026, 11, 1, 6);
    final s = CaughtUpStreak(clock: () => now);
    await s.load();
    expect(await s.markDone(), 1);
    expect(await s.markDone(), 1); // same day
    now = now.add(const Duration(days: 1));
    expect(await s.markDone(), 2);
    now = now.add(const Duration(days: 2));
    final again = CaughtUpStreak(clock: () => now);
    await again.load();
    expect(again.streak, 0);
  });
}
