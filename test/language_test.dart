import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';
import 'package:techdaily/core/constants/story_categories.dart';
import 'package:techdaily/core/constants/story_questions.dart';
import 'package:techdaily/l10n/app_language.dart';
import 'package:techdaily/l10n/strings.dart';
import 'package:techdaily/main.dart';
import 'package:techdaily/repositories/auth_repository.dart';
import 'package:techdaily/repositories/story_repository.dart';
import 'package:techdaily/services/v2/sample_stories.dart';
import 'package:techdaily/services/v2/saved_stories.dart';
import 'package:techdaily/services/v2/story_translator.dart';
import 'package:techdaily/services/v2/topic_prefs.dart';

class _NoNetwork implements TranslationApi {
  int calls = 0;
  @override
  Future<Map<String, TrFields>> translate(String lang, Map<String, TrFields> items) async {
    calls++;
    throw Exception('offline');
  }
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => appLanguage.resetForTest());

  test('language persists in SharedPreferences and the prompt is shown once', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AppLanguage();
    await a.load();
    expect(a.value, AppLang.en);
    expect(a.asked, isFalse);
    await a.set(AppLang.te);
    final b = AppLanguage();
    await b.load();
    expect(b.value, AppLang.te);
    expect(b.asked, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguage.prefsKey), 'te');

    SharedPreferences.setMockInitialValues({});
    final c = AppLanguage();
    await c.load();
    await c.dismissPrompt();
    final d = AppLanguage();
    await d.load();
    expect(d.asked, isTrue);
    expect(d.value, AppLang.en);
  });

  test('tr() translates UI strings, fills placeholders, falls back to English', () {
    expect(tr('Home'), 'Home');
    appLanguage.value = AppLang.hi;
    expect(tr('Home'), 'होम');
    expect(tr('Today in {n}', {'n': 5}), 'आज की 5 खबरें');
    expect(tr('Some new text'), 'Some new text');
    appLanguage.value = AppLang.te;
    expect(tr('Settings'), 'సెట్టింగ్స్');
    expect(storyCategoryById('scams-security').label, 'స్కామ్‌లు & సెక్యూరిటీ');
    expect(storyCategoryById('scams-security').enLabel, 'Scams & Security');
    expect(kScamQuestions.whatToDo.label, 'జాగ్రత్తగా ఉండండి');
  });

  test('Telugu and Hindi tables cover the same keys, including every category and question', () {
    for (final k in uiStringKeys) {
      expect(hasUiString(k, 'te'), isTrue, reason: 'te missing "$k"');
      expect(hasUiString(k, 'hi'), isTrue, reason: 'hi missing "$k"');
    }
    final labels = <String>{
      for (final c in [kTopStories, ...kStoryCategories]) ...[c.enLabel],
      for (final set in [kGeneralQuestions, kScamQuestions, ...kQuestionSets.values])
        ...[set.whatHappened.enLabel, set.affectsWho.enLabel, set.whatToDo.enLabel, set.whatItMeans.enLabel],
    };
    for (final l in labels) {
      expect(hasUiString(l, 'te'), isTrue, reason: 'te missing "$l"');
    }
  });

  testWidgets('switching to Hindi in Settings translates the nav; failed story translation shows English', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({AppLanguage.askedKey: true});
    final api = _NoNetwork();
    await tester.pumpWidget(TechDailyApp(
      stories: InMemoryStoryRepository(sampleStoryFeed()),
      authRepository: LocalAuthRepository(),
      saved: SavedStoriesController(),
      topics: TopicPrefs(),
      translator: StoryTranslator(api: api, debounce: Duration.zero),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-chip')), findsOneWidget);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lang-hi')));
    await tester.pumpAndSettle();
    expect(find.text('सेटिंग्स'), findsWidgets);
    expect(find.text('होम'), findsOneWidget);
    await tester.tap(find.text('होम'));
    await tester.pumpAndSettle();
    expect(api.calls, greaterThan(0)); // cards asked for a batch
    // The translation failed: English headlines stay, with a "Showing English" note.
    expect(find.text('A popular AI chatbot now talks in Hindi'), findsWidgets);
    expect(find.text('अंग्रेज़ी में दिखा रहे हैं'), findsWidgets);
    expect(tester.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguage.prefsKey), 'hi');
  });
}
