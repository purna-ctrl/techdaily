import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fonts.dart';
import 'package:techdaily/main.dart';
import 'package:techdaily/repositories/article_repository.dart';
import 'package:techdaily/repositories/auth_repository.dart';
import 'package:techdaily/services/local_article_service.dart';

void main() {
  setUpAll(loadAppFonts);
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(LocalArticleRepository, LocalAuthRepository)> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final repository = LocalArticleRepository(articleService: LocalArticleService());
    final authRepository = LocalAuthRepository();
    await tester.pumpWidget(TechDailyApp(repository: repository, authRepository: authRepository));
    await tester.pumpAndSettle();
    return (repository, authRepository);
  }

  testWidgets('App builds at 390px with wordmark, lead story and 5-tab navigation', (tester) async {
    await pumpApp(tester);

    expect(find.text('TechDaily'), findsWidgets);
    for (final label in ['Home', 'Quick Reads', 'Explore', 'Search', 'Saved']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // No seed/demo leftovers.
    expect(find.textContaining('seed', findRichText: true), findsNothing);
    expect(find.textContaining('Seed', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Browse by topic'), findsOneWidget);

    await tester.tap(find.text('Quick Reads').last);
    await tester.pumpAndSettle();
    expect(find.text('Read more'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search field accepts typing and filters results', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Find any story'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-field')));
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'HBM4');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const ValueKey('search-field')));
    expect(field.controller!.text, 'HBM4');
    expect(find.text('1 story found'), findsOneWidget);
  });

  testWidgets('Guests can save stories locally and see them in Saved', (tester) async {
    final (repo, auth) = await pumpApp(tester);
    await repo.toggleSaveArticle('', 'demo-hw-01');
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device'), findsOneWidget);
    expect(find.text('1 story'), findsOneWidget);

    await auth.signIn('reader@techdaily.com', 'password123');
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device'), findsNothing);
  });
}
