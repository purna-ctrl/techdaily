import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';
import 'package:techdaily/main.dart';
import 'package:techdaily/models/story.dart';
import 'package:techdaily/repositories/auth_repository.dart';
import 'package:techdaily/repositories/story_repository.dart';
import 'package:techdaily/services/v2/newsletter_service.dart';
import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/saved_stories.dart';
import 'package:techdaily/services/v2/topic_prefs.dart';
import 'package:techdaily/widgets/v3/category_art.dart';
import 'package:techdaily/widgets/v3/story_image.dart';

/// Sample feed where one story carries a (test-unreachable) publisher image.
StoryFeed _feed() {
  final f = sampleStoryFeed();
  final withImage = [
    for (final s in f.stories)
      s.id == 'demo-ai-1'
          ? Story.fromMap({
              ...s.toMap(),
              'image': {'url': 'https://img.example.com/ai.jpg', 'sourceName': 'Example Tech', 'sourceUrl': 'https://example.com/ai/hindi-voice', 'width': 1200, 'height': 675},
            })
          : s,
  ];
  return StoryFeed(stories: withImage, today: f.today, generatedAt: f.generatedAt);
}

void main() {
  setUpAll(loadAppFonts);
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(SavedStoriesController, LocalAuthRepository, LocalNewsletterService, TopicPrefs)> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository();
    final saved = SavedStoriesController();
    final newsletter = LocalNewsletterService();
    final topics = TopicPrefs();
    await tester.pumpWidget(TechDailyApp(
      stories: InMemoryStoryRepository(_feed()),
      authRepository: auth,
      saved: saved,
      newsletter: newsletter,
      topics: topics,
    ));
    await tester.pumpAndSettle();
    return (saved, auth, newsletter, topics);
  }

  Future<void> tapTab(WidgetTester tester, String id) async {
    final f = find.byKey(ValueKey('tab-$id'));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Scrolls [f] to the middle of the screen (clear of the pinned tab bar).
  Future<void> center(WidgetTester tester, Finder f) async {
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('Home: rings, pill tabs, hero, Scam Radar, Scam or Not, rails, 4-tab nav', (tester) async {
    await pumpApp(tester);
    expect(find.text('TechDaily'), findsWidgets);
    for (final label in ['Home', 'Search', 'Saved', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Today in 5'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('ring-$i')), findsOneWidget);
    }
    for (final id in ['top-stories', 'scams-security', 'ai', 'phones-gadgets']) {
      expect(find.byKey(ValueKey('tab-$id')), findsOneWidget, reason: id);
    }
    // Scam Radar carries the newest scam story; the hero is the next best story.
    expect(find.text('SCAM RADAR'), findsOneWidget);
    expect(find.text('Fake parcel texts are tricking UPI users'), findsWidgets);
    expect(find.text('A popular AI chatbot now talks in Hindi'), findsWidgets);
    await scrollTo(tester, find.text('Scam or Not?'));
    expect(find.byKey(const ValueKey('answer-scam')), findsOneWidget);
    await scrollTo(tester, find.text('Latest'));
    // Every image box has category art underneath (never blank)
    expect(find.byType(CategoryArtwork), findsWidgets);
    expect(tester.takeException(), isNull);

    await tapTab(tester, 'scams-security');
    expect(find.text('Fake parcel texts are tricking UPI users'), findsWidgets);
    expect(find.text('A popular AI chatbot now talks in Hindi'), findsNothing);
  });

  testWidgets('Images show a visible credit and fall back to category art when they fail', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'ai');
    expect(find.byType(ImageCredit), findsWidgets);
    expect(find.textContaining('Example Tech'), findsWidgets);
    // The image fails to load in tests: the art stays visible, no exception.
    expect(find.byType(CategoryArtwork), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Story detail: scam template, jargon sheet, action bar; Developing pill on low-confidence stories', (tester) async {
    await pumpApp(tester);
    await scrollTo(tester, find.text('Fake parcel texts are tricking UPI users').first);
    await tester.tap(find.text('Fake parcel texts are tricking UPI users').first);
    await tester.pumpAndSettle();
    for (final t in ['What happened', 'Does it affect me?', 'How the trick works', 'Warning signs', 'What to do if you’re targeted', 'What to do']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.byKey(const ValueKey('wa-demo-scam-1')), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-1930')), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('jargon-UPI')));
    await tester.tap(find.byKey(const ValueKey('jargon-UPI')));
    await tester.pumpAndSettle();
    expect(find.text('IN SIMPLE WORDS'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Read the originals'));
    await scrollTo(tester, find.text('Get “Today in 5” by email'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapTab(tester, 'phones-gadgets');
    expect(find.text('DEVELOPING'), findsWidgets);
  });

  testWidgets('Today in 5 viewer: tap through, then "You’re all caught up" with a streak', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('ring-0')));
    await tester.pumpAndSettle();
    expect(find.text('Swipe up for the full story'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(330, 420));
      await tester.pumpAndSettle();
    }
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget);
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('all caught up'), findsOneWidget); // rings header
  });

  testWidgets('Reels: vertical story pages with cards and the action bar', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('open-reels')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reels')), findsOneWidget);
    expect(find.text('SCAM ALERT'), findsOneWidget);
    expect(find.text('What happened'), findsWidgets);
    expect(find.text('WhatsApp'), findsWidgets);
    await tester.fling(find.byKey(const ValueKey('reels')), const Offset(0, -500), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2/6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scam or Not: answer, explanation, next, streak after the daily three', (tester) async {
    await pumpApp(tester);
    await scrollTo(tester, find.byKey(const ValueKey('answer-scam')));
    for (var i = 0; i < 3; i++) {
      await center(tester, find.byKey(const ValueKey('answer-scam')));
      await tester.tap(find.byKey(const ValueKey('answer-scam')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-explanation')), findsOneWidget);
      await center(tester, find.byKey(const ValueKey('game-next')));
      await tester.tap(find.byKey(const ValueKey('game-next')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('/ 3'), findsOneWidget);
    expect(find.text('🔥 1-day streak'), findsOneWidget);
  });

  testWidgets('Search filters stories', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Find any story'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'UPI');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('2 stories found'), findsOneWidget);
  });

  testWidgets('Guests save stories on the device; they show in Saved', (tester) async {
    final (saved, _, _, _) = await pumpApp(tester);
    final saveBtn = find.byKey(const ValueKey('save-demo-ai-1')).first;
    await center(tester, saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect(saved.isSaved('demo-ai-1'), isTrue);
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device'), findsWidgets);
    expect(find.text('1 story'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SavedStoriesController.prefsKey), contains('demo-ai-1'));
    expect(prefs.getString(SavedStoriesController.prefsKey), contains('img.example.com')); // image kept with the save
  });

  testWidgets('Settings: hiding a topic removes its tab; newsletter validates and signs up', (tester) async {
    final (_, _, newsletter, topics) = await pumpApp(tester);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-privacy')));
    await tester.pumpAndSettle();
    expect(topics.value, contains('privacy'));

    final field = find.byKey(const ValueKey('newsletter-email'));
    await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).last);
    await tester.enterText(field, 'not-an-email');
    await tester.tap(find.byKey(const ValueKey('newsletter-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    await tester.enterText(field, 'Reader@Example.com ');
    await tester.tap(find.byKey(const ValueKey('newsletter-submit')));
    await tester.pumpAndSettle();
    expect(newsletter.signups.single.$1, 'reader@example.com');
    expect(newsletter.signups.single.$2, 'app-settings');
    expect(find.byKey(const ValueKey('newsletter-done')), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tab-privacy')), findsNothing);
  });
}
