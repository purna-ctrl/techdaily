import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';
import 'package:techdaily/main.dart';
import 'package:techdaily/repositories/auth_repository.dart';
import 'package:techdaily/repositories/story_repository.dart';
import 'package:techdaily/services/v2/newsletter_service.dart';
import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/saved_stories.dart';
import 'package:techdaily/services/v2/topic_prefs.dart';

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
      stories: InMemoryStoryRepository(sampleStoryFeed()),
      authRepository: auth,
      saved: saved,
      newsletter: newsletter,
      topics: topics,
    ));
    await tester.pumpAndSettle();
    return (saved, auth, newsletter, topics);
  }

  testWidgets('Home: category tabs in order, Today in 5, full story cards, 4-tab nav', (tester) async {
    await pumpApp(tester);
    expect(find.text('TechDaily'), findsWidgets);
    for (final label in ['Home', 'Search', 'Saved', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    for (final tab in ['Top Stories', 'Scams & Security', 'AI', 'Phones & Gadgets']) {
      expect(find.widgetWithText(Tab, tab), findsOneWidget, reason: tab);
    }
    expect(find.text('Today in 5 stories'), findsOneWidget);
    // Card fields
    expect(find.text('What happened'), findsWidgets);
    expect(find.text('Does it affect me?'), findsWidgets);
    expect(find.text('What to do'), findsWidgets);
    expect(find.text('What this means for you'), findsWidgets);
    expect(find.text('WhatsApp'), findsWidgets);
    expect(find.textContaining('Read original'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(Tab, 'Scams & Security'));
    await tester.pumpAndSettle();
    expect(find.text('Fake parcel texts are tricking UPI users'), findsWidgets);
  });

  testWidgets('Story detail shows the scam template and Developing badge appears on low-confidence stories', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Fake parcel texts are tricking UPI users').first);
    await tester.pumpAndSettle();
    expect(find.text('How the trick works'), findsOneWidget);
    expect(find.text('Warning signs'), findsOneWidget);
    expect(find.text('What to do if you’re targeted'), findsOneWidget);
    expect(find.text('Read the originals'), findsOneWidget);
    expect(find.text('Get “Today in 5” by email'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Phones & Gadgets'));
    await tester.pumpAndSettle();
    expect(find.text('DEVELOPING'), findsWidgets);
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
    final (saved, auth, _, _) = await pumpApp(tester);
    final saveBtn = find.byKey(const ValueKey('save-demo-scam-1')).first;
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect(saved.isSaved('demo-scam-1'), isTrue);
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device'), findsWidgets);
    expect(find.text('1 story'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SavedStoriesController.prefsKey), contains('demo-scam-1'));
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
    expect(find.widgetWithText(Tab, 'Privacy'), findsNothing);
  });
}
