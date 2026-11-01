import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fonts.dart';
import 'package:techdaily/core/app_scope.dart';
import 'package:techdaily/core/theme/app_theme.dart';
import 'package:techdaily/models/article.dart';
import 'package:techdaily/repositories/article_repository.dart';
import 'package:techdaily/repositories/auth_repository.dart';
import 'package:techdaily/repositories/guest_bookmark_store.dart';
import 'package:techdaily/screens/article_screen.dart';
import 'package:techdaily/screens/auth_screen.dart';
import 'package:techdaily/screens/quick_reads_screen.dart';
import 'package:techdaily/services/article_ai_assistant_service.dart';
import 'package:techdaily/services/home_feed_service.dart';
import 'package:techdaily/services/local_article_service.dart';
import 'package:techdaily/services/share_service.dart';

Article _a(String id, {String cat = 'Software', bool breaking = false, String region = 'GLOBAL', int hoursAgo = 1}) =>
    Article(
      id: id,
      title: 'Story $id',
      summary: 'Summary $id',
      simpleExplanation: 'Simple $id',
      category: cat,
      sourceName: 'Google Official Blog',
      sourceUrl: 'https://www.blog.google/technology/ai/$id/',
      publishedAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
      keyPoints: const ['Point'],
      isBreaking: breaking,
      region: region,
    );

void main() {
  setUpAll(loadAppFonts);
  group('Home feed dedupe', () {
    test('every article appears in at most one home section', () {
      final articles = [
        for (var i = 0; i < 30; i++)
          _a('a$i',
              cat: ['AI & Machine Learning', 'Software', 'Hardware', 'Cloud', 'Science'][i % 5],
              breaking: i % 7 == 0,
              region: i % 6 == 0 ? 'IN' : 'GLOBAL',
              hoursAgo: i + 1),
      ];
      final feed = HomeFeedComposer().compose(articles);
      final ids = feed.placedIds;
      expect(ids.toSet().length, ids.length, reason: 'duplicate ids: $ids');
      expect(feed.lead, isNotNull);
      expect(feed.trending, isNotEmpty);
      expect(feed.india.every((a) => a.isIndia), isTrue);
    });

    test('sample data feed has no duplicates and duplicate input ids collapse', () {
      final sample = LocalArticleService.sampleArticles;
      final feed = HomeFeedComposer().compose([...sample, ...sample]);
      final ids = feed.placedIds;
      expect(ids.toSet().length, ids.length);
      expect(feed.india, isEmpty); // sample data has no IN stories → India hidden
    });
  });

  group('Article model additions', () {
    test('region defaults to GLOBAL and translations parse', () {
      final a = Article.fromMap({
        'title': 't',
        'sourceUrl': 'https://www.theverge.com/x',
        'simpleExplanationTranslations': {'te': 'తెలుగు', 'ta': '', 'hi': 'हिंदी', 'x': 3},
      }, docId: 'd1');
      expect(a.region, 'GLOBAL');
      expect(a.simpleExplanationTranslations, {'te': 'తెలుగు', 'hi': 'हिंदी'});
      expect(a.sourceDomain, 'theverge.com');
      final india = Article.fromMap({'title': 't', 'region': 'in'}, docId: 'd2');
      expect(india.isIndia, isTrue);
    });

    test('language toggle options only include present translations', () {
      final a = _a('x').copyWith(simpleExplanationTranslations: {'hi': 'नमस्ते'});
      expect(SimpleWordsLanguage.availableFor(a).map((l) => l.code), ['en', 'hi']);
      expect(SimpleWordsLanguage.availableFor(_a('y')).length, 1);
    });
  });

  group('Ask AI backend', () {
    test('uses backend answer on 200', () async {
      late Map body;
      final client = MockClient((req) async {
        body = jsonDecode(req.body) as Map;
        return http.Response(jsonEncode({'answer': 'Backend says hi'}), 200,
            headers: {'content-type': 'application/json'});
      });
      final svc = ArticleAiAssistantService(client: client, endpoint: 'https://example.test/ask');
      final res = await svc.ask(_a('q1'), 'What is this?');
      expect(res.text, 'Backend says hi');
      expect(res.source, AiAnswerSource.backend);
      expect(body, {'articleId': 'q1', 'question': 'What is this?'});
    });

    test('falls back to grounded answer on failure', () async {
      final client = MockClient((req) async => http.Response('boom', 500));
      final svc = ArticleAiAssistantService(client: client, endpoint: 'https://example.test/ask');
      final res = await svc.ask(_a('q2'), 'Explain this simply');
      expect(res.source, AiAnswerSource.localFallback);
      expect(res.text, 'Simple q2');
    });
  });

  group('Sharing & deep links', () {
    test('share text contains title, app link and exact source link', () {
      final a = _a('abc');
      final text = ShareService.shareText(a);
      expect(text, contains('Story abc'));
      expect(text, contains('https://techdaily-prod.web.app/article/abc'));
      expect(text, contains(a.sourceUrl));
    });

    test('article route parsing', () {
      expect(articleIdFromRoute('/article/abc-1'), 'abc-1');
      expect(articleIdFromRoute('/article/abc-1/'), 'abc-1');
      expect(articleIdFromRoute('/article'), isNull);
      expect(articleIdFromRoute('/'), isNull);
      expect(articleRoutePath('a b'), '/article/a%20b');
    });
  });

  group('Guest bookmarks', () {
    test('guest store round-trips and clears', () async {
      SharedPreferences.setMockInitialValues({});
      const store = GuestBookmarkStore();
      expect(await store.load(), isEmpty);
      await store.save({'a', 'b'});
      expect(await store.load(), {'a', 'b'});
      await store.clear();
      expect(await store.load(), isEmpty);
    });

    test('local repository resolves saved ids in order', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalArticleRepository();
      final got = await repo.getArticlesByIds(['demo-hw-01', 'missing', 'demo-ai-01']);
      expect(got.map((a) => a.id), ['demo-hw-01', 'demo-ai-01']);
    });
  });

  group('Small helpers', () {
    test('trimToWords caps at 60 words', () {
      final long = List.filled(80, 'word').join(' ');
      final out = trimToWords(long);
      expect(out.split(' ').length, 60);
      expect(out.endsWith('…'), isTrue);
      expect(trimToWords('short text'), 'short text');
    });

    test('password rules', () {
      expect(PasswordRules.isValid('abc12345'), isTrue);
      expect(PasswordRules.isValid('abcdefgh'), isFalse);
      expect(PasswordRules.isValid('a1'), isFalse);
    });

    test('numeric style uses tabular figures and no letter spacing', () {
      final s = AppTheme.numeric(12);
      expect(s.letterSpacing, 0);
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('Screens', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
          theme: b == Brightness.light ? AppTheme.light() : AppTheme.dark(),
          home: child,
        );

    testWidgets('article screen shows simple words toggle and same domain on source + button',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = LocalArticleRepository();
      final article = LocalArticleService.sampleArticles.first; // has te/ta/hi
      await tester.pumpWidget(wrap(ArticleScreen(article: article, repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('In simple words'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);
      await tester.ensureVisible(find.text('हिंदी'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();
      expect(find.text(article.simpleExplanationTranslations['hi']!), findsOneWidget);

      final domain = article.sourceDomain;
      expect(find.textContaining(domain), findsWidgets);
      await tester.scrollUntilVisible(find.text('Read original on $domain'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Read original on $domain'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('article without translations hides the language toggle (dark mode)', (tester) async {
      final repo = LocalArticleRepository();
      final article = LocalArticleService.sampleArticles[1];
      await tester.pumpWidget(wrap(ArticleScreen(article: article, repository: repo), b: Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.text('In simple words'), findsOneWidget);
      expect(find.text('हिंदी'), findsNothing);
    });

    testWidgets('quick reads shows one story per page with Read more', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(QuickReadsScreen(repository: LocalArticleRepository())));
      await tester.pumpAndSettle();
      expect(find.text('Quick Reads'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
      expect(find.textContaining('1 / '), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auth screen: renamed labels, fields accept text, show/hide password', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(AuthScreen(authRepository: LocalAuthRepository(), initialIsSignUp: true)));
      await tester.pumpAndSettle();
      expect(find.text('Subscriber Login'), findsNothing);
      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.textContaining('Privacy Policy', findRichText: true), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('auth-email')), 'me@example.com');
      await tester.enterText(find.byKey(const ValueKey('auth-password')), 'abc12345');
      await tester.pump();
      expect(find.text('me@example.com'), findsOneWidget);
      final pwd = tester.widget<EditableText>(
          find.descendant(of: find.byKey(const ValueKey('auth-password')), matching: find.byType(EditableText)));
      expect(pwd.obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      final pwd2 = tester.widget<EditableText>(
          find.descendant(of: find.byKey(const ValueKey('auth-password')), matching: find.byType(EditableText)));
      expect(pwd2.obscureText, isFalse);
    });
  });
}
