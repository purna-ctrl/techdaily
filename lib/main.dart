import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_scope.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/stories_scope.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_language.dart';
import 'l10n/indic_fonts.dart';
import 'models/article.dart';
import 'models/story.dart';
import 'repositories/article_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/firestore_article_repository.dart';
import 'repositories/story_repository.dart';
import 'screens/article_screen.dart';
import 'screens/v2/home_feed_screen.dart';
import 'screens/v2/scam_check_screen.dart';
import 'screens/v2/saved_stories_screen.dart';
import 'screens/v2/settings_screen.dart';
import 'screens/v2/story_detail_screen.dart';
import 'screens/v2/story_search_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_article_service.dart';
import 'services/v2/daily_streak.dart';
import 'services/v2/newsletter_service.dart';
import 'services/v2/scam_game.dart';
import 'services/v2/story_translator.dart';
import 'services/v2/sample_stories.dart';
import 'services/v2/saved_stories.dart';
import 'services/v2/topic_prefs.dart';
import 'widgets/story_widgets.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs on web (`/app/story/<slug>` instead of `/#/...`).
  usePathUrlStrategy();

  bool firebaseReady = false;
  if (kDataSource != 'local') {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (Firebase.apps.isEmpty) {
        // Time-boxed: if the Firebase SDK is blocked (ad blockers, flaky network) the
        // app still starts and reads stories from /data/feed.json.
        await (options != null ? Firebase.initializeApp(options: options) : Firebase.initializeApp())
            .timeout(const Duration(seconds: 8));
      }
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase initialization notice (running offline/fallback): $e');
    }
  }

  final StoryRepository stories;
  final AuthRepository auth;
  final ArticleRepository legacyArticles;
  final SavedStoriesController saved;
  final NewsletterService newsletter;
  if (firebaseReady) {
    stories = HostedStoryRepository(firestore: FirebaseFirestore.instance);
    auth = FirebaseAuthService();
    legacyArticles = FirestoreArticleRepository();
    saved = SavedStoriesController(remote: FirestoreSavedStoriesRemote());
    newsletter = FirestoreNewsletterService();
    unawaited(_listenForForegroundPush());
  } else {
    // Offline demo uses bundled sample stories; if Firebase merely failed to start,
    // stories still load from the pre-rendered /data/feed.json.
    stories = kDataSource == 'local' ? InMemoryStoryRepository(sampleStoryFeed()) : HostedStoryRepository();
    auth = LocalAuthRepository();
    legacyArticles = LocalArticleRepository(articleService: LocalArticleService());
    saved = SavedStoriesController();
    newsletter = LocalNewsletterService();
  }

  runApp(TechDailyApp(
    stories: stories,
    authRepository: auth,
    legacyArticles: legacyArticles,
    saved: saved,
    newsletter: newsletter,
  ));
}

String? _routeFromPush(RemoteMessage? m) {
  final slug = m?.data['slug'] as String?;
  if (slug != null && slug.isNotEmpty) return storyRoutePath(slug);
  final articleId = m?.data['articleId'] as String?;
  if (articleId != null && articleId.isNotEmpty) return articleRoutePath(articleId);
  return null;
}

/// Snackbar for pushes received while the app is open; opens the story when a
/// notification is tapped. Fully guarded.
Future<void> _listenForForegroundPush() async {
  try {
    if (!await FirebaseMessaging.instance.isSupported()) return;
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title;
      if (title == null) return;
      final route = _routeFromPush(message);
      rootMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('$title: ${message.notification?.body ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: route == null
            ? null
            : SnackBarAction(label: 'Read', onPressed: () => rootNavigatorKey.currentState?.pushNamed(route)),
      ));
    });
    void openFrom(RemoteMessage? m) {
      final route = _routeFromPush(m);
      if (route != null) rootNavigatorKey.currentState?.pushNamed(route);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(openFrom);
    if (!kIsWeb) openFrom(await FirebaseMessaging.instance.getInitialMessage());
  } catch (e) {
    debugPrint('Push listeners unavailable: $e');
  }
}

class TechDailyApp extends StatefulWidget {
  final StoryRepository stories;
  final AuthRepository authRepository;
  final ArticleRepository? legacyArticles;
  final SavedStoriesController? saved;
  final TopicPrefs? topics;
  final NewsletterService? newsletter;

  /// Story translation (Telugu / Hindi); tests pass a fake.
  final StoryTranslator? translator;

  const TechDailyApp({
    super.key,
    required this.stories,
    required this.authRepository,
    this.legacyArticles,
    this.saved,
    this.topics,
    this.newsletter,
    this.translator,
  });

  @override
  State<TechDailyApp> createState() => _TechDailyAppState();
}

class _TechDailyAppState extends State<TechDailyApp> {
  // TechDaily is dark-first (ink #0B0B0F).
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  late final SavedStoriesController _saved = widget.saved ?? SavedStoriesController();
  late final TopicPrefs _topics = widget.topics ?? TopicPrefs();
  late final NewsletterService _newsletter = widget.newsletter ?? LocalNewsletterService();
  final ScamGameController _scamGame = ScamGameController();
  final CaughtUpStreak _caughtUp = CaughtUpStreak();
  late final ArticleRepository _legacy = widget.legacyArticles ?? LocalArticleRepository(articleService: LocalArticleService());
  late final StoryTranslator _translator = widget.translator ?? StoryTranslator();
  StreamSubscription<dynamic>? _authSub;
  AppLang _lang = appLanguage.value;

  void _onLanguage() {
    final l = appLanguage.value;
    _translator.setLanguage(l.code);
    if (l != AppLang.en) unawaited(ensureIndicFonts());
    if (l != _lang) {
      _lang = l;
      // Const widgets and plain getters (category names) read the language
      // directly, so repaint everything once; navigation and state are kept.
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllForLanguage());
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onLanguage);
    _translator.setLanguage(appLanguage.value.code);
    unawaited(_translator.init());
    unawaited(appLanguage.load().then((_) {
      // `?lang=te|hi|en` on any web link picks the language (shareable links, checks).
      final q = kIsWeb ? Uri.base.queryParameters['lang'] : null;
      if (q != null && AppLang.values.any((l) => l.code == q)) unawaited(appLanguage.set(AppLang.fromCode(q)));
    }));
    if (widget.topics == null) unawaited(_topics.load());
    unawaited(_scamGame.load());
    unawaited(_caughtUp.load());
    unawaited(_saved.bind(widget.authRepository.currentUser?.uid));
    _authSub = widget.authRepository.authStateChanges.listen((u) => _saved.bind(u?.uid));
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguage);
    if (widget.translator == null) _translator.dispose();
    _authSub?.cancel();
    _themeModeNotifier.dispose();
    _scamGame.dispose();
    _caughtUp.dispose();
    super.dispose();
  }

  Route<dynamic> _shell(RouteSettings settings, {int tab = 0, String? category, String? query}) => MaterialPageRoute(
        settings: settings,
        builder: (_) => TechDailyMainShell(initialTab: tab, initialCategory: category, initialQuery: query),
      );

  Route<dynamic>? _routeFor(RouteSettings settings) {
    final r = AppRoute.parse(settings.name);
    switch (r.kind) {
      case AppRouteKind.home:
        return _shell(const RouteSettings(name: '/'));
      case AppRouteKind.story:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => StoryRouteScreen(slug: r.param!, initial: settings.arguments is Story ? settings.arguments as Story : null),
        );
      case AppRouteKind.category:
        return _shell(settings, category: r.param);
      case AppRouteKind.search:
        return _shell(settings, tab: 1, query: r.param);
      case AppRouteKind.saved:
        return _shell(settings, tab: 2);
      case AppRouteKind.settings:
        return _shell(settings, tab: 3);
      case AppRouteKind.newsletter:
        return MaterialPageRoute(settings: settings, builder: (_) => NewsletterScreen(email: r.param));
      case AppRouteKind.about:
        return MaterialPageRoute(settings: settings, builder: (_) => const AboutScreen());
      case AppRouteKind.scamCheck:
        return MaterialPageRoute(settings: settings, builder: (_) => ScamCheckScreen(initialText: r.param));
      case AppRouteKind.legacyArticle:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ArticleRouteScreen(
            articleId: r.param!,
            initialArticle: settings.arguments is Article ? settings.arguments as Article : null,
            repository: _legacy,
            authRepository: widget.authRepository,
          ),
        );
      case AppRouteKind.unknown:
        return null;
    }
  }

  /// Deep links: the home feed sits under a story/about page so Back works.
  List<Route<dynamic>> _initialRoutes(String name) {
    final r = AppRoute.parse(name);
    final route = _routeFor(RouteSettings(name: name));
    if (route == null || r.kind == AppRouteKind.home) return [_shell(const RouteSettings(name: '/'))];
    final overShell = {AppRouteKind.story, AppRouteKind.newsletter, AppRouteKind.about, AppRouteKind.scamCheck, AppRouteKind.legacyArticle};
    return overShell.contains(r.kind) ? [_shell(const RouteSettings(name: '/')), route] : [route];
  }

  @override
  Widget build(BuildContext context) {
    return StoriesScope(
      stories: widget.stories,
      saved: _saved,
      topics: _topics,
      newsletter: _newsletter,
      auth: widget.authRepository,
      scamGame: _scamGame,
      caughtUp: _caughtUp,
      translator: _translator,
      child: AppScope(
        repository: _legacy,
        authRepository: widget.authRepository,
        themeModeNotifier: _themeModeNotifier,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _themeModeNotifier,
          builder: (context, mode, _) => MaterialApp(
            title: kAppTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            scrollBehavior: const _AppScrollBehavior(),
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootMessengerKey,
            initialRoute: '/',
            onGenerateInitialRoutes: _initialRoutes,
            onGenerateRoute: _routeFor,
            onUnknownRoute: (settings) => _shell(const RouteSettings(name: '/')),
          ),
        ),
      ),
    );
  }
}

/// Legacy v1 deep links (`/article/<id>`) still open the old article screen.
class ArticleRouteScreen extends StatefulWidget {
  final String articleId;
  final Article? initialArticle;
  final ArticleRepository repository;
  final AuthRepository authRepository;

  const ArticleRouteScreen({
    super.key,
    required this.articleId,
    this.initialArticle,
    required this.repository,
    required this.authRepository,
  });

  @override
  State<ArticleRouteScreen> createState() => _ArticleRouteScreenState();
}

class _ArticleRouteScreenState extends State<ArticleRouteScreen> {
  late Future<Article?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initialArticle != null ? Future.value(widget.initialArticle) : widget.repository.getArticleById(widget.articleId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Article?>(
      future: _future,
      builder: (context, snap) {
        final article = snap.data;
        if (article != null) {
          return ArticleScreen(article: article, repository: widget.repository, authRepository: widget.authRepository);
        }
        final loading = snap.connectionState != ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: tr('Home'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                final nav = Navigator.of(context);
                nav.canPop() ? nav.pop() : nav.pushReplacementNamed('/');
              },
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : FriendlyState(
                  icon: Icons.article_outlined,
                  title: tr('Story not found'),
                  message: 'This older link has moved. Here’s what’s new instead.',
                  actionLabel: tr('Go to home'),
                  actionIcon: Icons.home_rounded,
                  onAction: () => Navigator.of(context).pushReplacementNamed('/'),
                ),
        );
      },
    );
  }
}

/// Bottom navigation: Home · Search · Saved · Settings.
class TechDailyMainShell extends StatefulWidget {
  final int initialTab;
  final String? initialCategory;
  final String? initialQuery;
  const TechDailyMainShell({super.key, this.initialTab = 0, this.initialCategory, this.initialQuery});

  @override
  State<TechDailyMainShell> createState() => _TechDailyMainShellState();
}

class _TechDailyMainShellState extends State<TechDailyMainShell> {
  late int _index = widget.initialTab.clamp(0, 3);
  late final Set<int> _visited = {_index};

  Widget _screen(int i) {
    switch (i) {
      case 0:
        return HomeFeedScreen(initialCategory: widget.initialCategory);
      case 1:
        return StorySearchScreen(initialQuery: widget.initialQuery);
      case 2:
        return const SavedStoriesScreen();
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(4, (i) => _visited.contains(i) ? _screen(i) : const SizedBox.shrink()),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderOf(context)))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: tr('Home')),
            NavigationDestination(icon: const Icon(Icons.search_rounded), label: tr('Search')),
            NavigationDestination(icon: const Icon(Icons.bookmark_border_rounded), selectedIcon: const Icon(Icons.bookmark_rounded), label: tr('Saved')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings_rounded), label: tr('Settings')),
          ],
        ),
      ),
    );
  }
}

/// Lets mouse/trackpad users drag lists on web/desktop.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// Exposed for tests and the web title.
const String kAppTitle = '${AppConstants.appName} — Tech news in simple words';
