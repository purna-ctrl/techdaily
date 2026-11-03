import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techdaily/core/constants/story_categories.dart';
import 'package:techdaily/core/constants/story_questions.dart';
import 'package:techdaily/models/story.dart';
import 'package:techdaily/services/v2/story_ask.dart';
import 'package:techdaily/widgets/v3/story_questions.dart';

Story _story({
  String category = 'space',
  String aiModel = 'gemini-flash-lite-latest',
  String promptVersion = 'stories-v3',
  List<String> whatToDo = const ['The satellite can spot cloud changes every 15 minutes.'],
  String goodToKnow = '',
  String whatItMeans = 'ISRO plans a second satellite next year.',
}) =>
    Story.fromMap({
      'id': 'st-1',
      'slug': 'isro-weather-sat',
      'headline': 'ISRO puts a new weather satellite in orbit',
      'category': category,
      'publishedAt': '2026-11-03T05:00:00Z',
      'sources': [
        {'name': 'ISRO', 'url': 'https://www.isro.gov.in/x', 'title': 'PSLV-C62 success', 'publishedAt': '2026-11-03T05:00:00Z'}
      ],
      'tldr': 'ISRO launched a weather satellite that will improve monsoon forecasts.',
      'keyNumbers': [
        {'value': '1,450 kg', 'label': 'Satellite weight'},
        {'value': '₹420 crore', 'label': 'Mission cost'},
        {'value': '', 'label': 'dropped'},
      ],
      'whatHappened': 'A PSLV rocket carried the satellite from Sriharikota on Monday.',
      'affectsWho': 'Better weather data helps farmers and fishermen plan ahead.',
      'whatToDo': whatToDo,
      'goodToKnow': goodToKnow,
      'whatItMeans': whatItMeans,
      'faq': [
        {'q': 'Can I see the satellite from India?', 'a': 'No, it is too far away to see without a telescope.'},
        {'q': 'When is the next launch?', 'a': 'ISRO plans a second satellite next year.'},
      ],
      'aiModel': aiModel,
      'promptVersion': promptVersion,
    });

void main() {
  group('question sets', () {
    test('every category has a tailored set; scams get the scam set', () {
      for (final c in kStoryCategories) {
        expect(kQuestionSets[c.id], isNotNull, reason: c.id);
      }
      final s = _story();
      expect(s.questions.whatToDo.label, 'Cool fact');
      expect(s.questions.todoStyle, ListStyle.fact);
      expect(questionsFor('phones-gadgets').whatToDo.label, 'Price & availability in India');
      expect(questionsFor('scams-security', isScam: true).whatHappened.label, 'What’s the trick?');
      expect(questionsFor('unknown'), kGeneralQuestions);
    });

    test('model reads tldr, key numbers and faq; round-trips', () {
      final s = _story();
      expect(s.tldr, contains('weather satellite'));
      expect(s.keyNumbers.map((k) => k.value), ['1,450 kg', '₹420 crore']);
      expect(s.faq, hasLength(2));
      final back = Story.fromMap(s.toMap());
      expect(back.faq.first.q, s.faq.first.q);
      expect(back.keyNumbers.length, 2);
      expect(back.promptVersion, 'stories-v3');
    });

    test('legacy fallback boilerplate is never shown', () {
      final s = Story.fromMap({
        'id': 'x',
        'slug': 'x',
        'headline': 'NASA rocket',
        'category': 'space',
        'publishedAt': '2026-11-01T00:00:00Z',
        'whatHappened': 'NASA reported: NASA rocket. This short version was written automatically — open the original report for full details.',
        'affectsWho': 'No one directly yet — this is about space missions and satellite technology.',
        'whatToDo': ['Nothing to do — open the original report if you want the details.'],
        'whatItMeans': 'Space technology powers everyday things like maps, weather forecasts and satellite internet.',
        'aiModel': 'techdaily-fallback-v2',
        'promptVersion': 'stories-v2',
      });
      final d = s.display;
      expect(d.whatHappened, isEmpty);
      expect(d.affectsWho, isEmpty);
      expect(d.whatToDo, isEmpty);
      expect(d.whatItMeans, isEmpty);
    });
  });

  group('ask about this (on device)', () {
    test('matches the FAQ, the jargon dictionary, sections, and says when it cannot answer', () {
      final s = _story();
      expect(answerLocally(s, 'can i see the satellite?').source, AskSource.faq);
      final j = answerLocally(s, 'What does OTP mean?');
      expect(j.source, AskSource.jargon);
      expect(j.text, startsWith('OTP'));
      final cost = answerLocally(s, 'how much did it cost');
      expect(cost.text, contains('₹420 crore'));
      expect(answerLocally(s, 'who is affected by this?').text, contains('farmers'));
      expect(answerLocally(s, 'Where did the rocket take off from?').text, contains('Sriharikota'));
      final none = answerLocally(s, 'Will Bitcoin go up tomorrow?');
      expect(none.unanswered, isTrue);
      expect(none.text, contains('sources'));
    });

    test('uses ASK_ENDPOINT when set and falls back to the device when it fails', () async {
      Map<String, dynamic>? sent;
      final ok = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'answer': 'From the worker.'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final s = _story();
      final a = await StoryAskService(endpoint: 'https://ask.example/ask', client: ok).ask(s, 'Why does this matter?');
      expect(a.source, AskSource.remote);
      expect(a.text, 'From the worker.');
      expect(sent!['slug'], 'isro-weather-sat');
      expect(sent!['question'], 'Why does this matter?');
      expect((sent!['story'] as Map)['headline'], s.headline);
      final long = await StoryAskService(endpoint: 'https://ask.example/ask', client: ok).ask(s, 'x' * 500);
      expect((sent!['question'] as String).length, 300);
      expect(long.source, AskSource.remote);
      final down = MockClient((_) async => http.Response('nope', 503));
      final b = await StoryAskService(endpoint: 'https://ask.example/ask', client: down).ask(s, 'can i see the satellite?');
      expect(b.source, AskSource.faq);
      // Empty endpoint: never calls the network.
      final c = await const StoryAskService(endpoint: '').ask(s, 'When is the next launch?');
      expect(c.source, AskSource.faq);
    });
  });

  group('widgets', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
      await tester.pumpAndSettle();
    }

    testWidgets('top block: one-liner, key numbers, fallback pill', (tester) async {
      await pump(tester, StoryTopBlock(story: _story(aiModel: 'techdaily-fallback-v3')));
      expect(find.text('IN ONE LINE'), findsOneWidget);
      expect(find.text('KEY NUMBERS'), findsOneWidget);
      expect(find.text('1,450 kg'), findsOneWidget);
      expect(find.text(kFallbackPill), findsOneWidget);
    });

    testWidgets('space sections use the space questions; Good to know replaces an empty checklist', (tester) async {
      final s = _story();
      expect(storySections(s).map((x) => x.title), ['What happened?', 'Why should I care?', 'Cool fact', 'What’s next']);
      final t = _story(category: 'money-fintech', whatToDo: const [], goodToKnow: 'You never need your UPI PIN to receive money.', whatItMeans: '');
      expect(storySections(t).map((x) => x.title), ['What changed?', 'Does it affect my money?', 'Good to know']);
    });

    testWidgets('FAQ chips expand; ask box answers from the story', (tester) async {
      await pump(tester, AskAboutThis(story: _story(), service: const StoryAskService(endpoint: ''), onOpenSources: () {}));
      expect(find.text('No, it is too far away to see without a telescope.'), findsNothing);
      await tester.tap(find.text('Can I see the satellite from India?'));
      await tester.pumpAndSettle();
      expect(find.text('No, it is too far away to see without a telescope.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('ask-field')), 'Will it rain tomorrow in Delhi?');
      await tester.tap(find.byKey(const ValueKey('ask-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-answer')), findsOneWidget);
      expect(find.text('Read the sources'), findsOneWidget);
    });
  });
}
