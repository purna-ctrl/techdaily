import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_scope.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'models/article.dart';
import 'repositories/article_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/firestore_article_repository.dart';
import 'screens/article_screen.dart';
import 'screens/category_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quick_reads_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_article_service.dart';
import 'widgets/bottom_navigation.dart';
import 'widgets/story_widgets.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs on web (`/article/<id>` instead of `/#/article/<id>`).
  usePathUrlStrategy();

  ArticleRepository articleRepository;
  AuthRepository authRepository;

  bool isFirebaseInitialized = false;
  if (kDataSource != 'local') {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }
      isFirebaseInitialized = true;
    } catch (e) {
      debugPrint('Firebase initialization notice (running offline/fallback): $e');
    }
  }

  if (isFirebaseInitialized) {
    final firestoreRepo = FirestoreArticleRepository();
    articleRepository = firestoreRepo;
    authRepository = FirebaseAuthService();

    // Bind bookmarks to the signed-in user; guest saves merge in on sign-in.
    unawaited(firestoreRepo.bindUserBookmarks(authRepository.currentUser?.uid));
    authRepository.authStateChanges.listen((user) {
      firestoreRepo.bindUserBookmarks(user?.uid);
    });
    unawaited(_listenForForegroundPush(articleRepository));
  } else {
    articleRepository = LocalArticleRepository(articleService: LocalArticleService());
    authRepository = LocalAuthRepository();
  }

  runApp(TechDailyApp(
    repository: articleRepository,
    authRepository: authRepository,
  ));
}

/// Shows a snackbar for pushes received while the app is open and opens the
/// article when a notification carrying `articleId` is tapped. Fully guarded.
Future<void> _listenForForegroundPush(ArticleRepository repository) async {
  try {
    if (!await FirebaseMessaging.instance.isSupported()) return;
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title;
      if (title == null) return;
      final articleId = message.data['articleId'] as String?;
      rootMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        action: articleId == null
            ? null
            : SnackBarAction(
                label: 'Read',
                onPressed: () => rootNavigatorKey.currentState?.pushNamed(articleRoutePath(articleId)),
              ),
      ));
    });
    void openFrom(RemoteMessage? m) {
      final id = m?.data['articleId'] as String?;
      if (id != null && id.isNotEmpty) {
        rootNavigatorKey.currentState?.pushNamed(articleRoutePath(id));
      }
    }

    FirebaseMessaging.onMessageOpenedApp.listen(openFrom);
    if (!kIsWeb) openFrom(await FirebaseMessaging.instance.getInitialMessage());
  } catch (e) {
    debugPrint('Push listeners unavailable: $e');
  }
}

class TechDailyApp extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository authRepository;

  const TechDailyApp({
    super.key,
    required this.repository,
    required this.authRepository,
  });

  @override
  State<TechDailyApp> createState() => _TechDailyAppState();
}

class _TechDailyAppState extends State<TechDailyApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final articleId = articleIdFromRoute(name);
    if (articleId != null) {
      final initial = settings.arguments is Article ? settings.arguments as Article : null;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => ArticleRouteScreen(
          articleId: articleId,
          initialArticle: initial,
          repository: widget.repository,
          authRepository: widget.authRepository,
        ),
      );
    }
    if (name == '/' || name.isEmpty) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => TechDailyMainShell(
          repository: widget.repository,
          authRepository: widget.authRepository,
          themeModeNotifier: _themeModeNotifier,
        ),
      );
    }
    // Intermediate path segments (e.g. '/article') are skipped.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: widget.repository,
      authRepository: widget.authRepository,
      themeModeNotifier: _themeModeNotifier,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeModeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'TechDaily — Tech news in simple words',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: currentMode,
            scrollBehavior: const _AppScrollBehavior(),
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootMessengerKey,
            initialRoute: '/',
            onGenerateRoute: _onGenerateRoute,
            onUnknownRoute: (settings) => MaterialPageRoute(
              settings: const RouteSettings(name: '/'),
              builder: (_) => TechDailyMainShell(
                repository: widget.repository,
                authRepository: widget.authRepository,
                themeModeNotifier: _themeModeNotifier,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loads an article by id for deep links (`/article/<id>`).
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
    _future = widget.initialArticle != null
        ? Future.value(widget.initialArticle)
        : _fetch();
  }

  Future<Article?> _fetch() async {
    try {
      return await widget.repository.getArticleById(widget.articleId);
    } catch (e) {
      debugPrint('Deep link fetch failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Article?>(
      future: _future,
      builder: (context, snap) {
        final article = snap.data;
        if (article != null) {
          return ArticleScreen(
            article: article,
            repository: widget.repository,
            authRepository: widget.authRepository,
          );
        }
        final loading = snap.connectionState != ConnectionState.done;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Home',
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
                  icon: snap.hasError ? Icons.wifi_off_rounded : Icons.article_outlined,
                  title: snap.hasError ? 'Couldn’t load this story' : 'Story not found',
                  message: snap.hasError
                      ? 'Check your connection and try again.'
                      : 'It may have been removed. Here’s what’s new instead.',
                  actionLabel: snap.hasError ? 'Try again' : 'Go to home',
                  actionIcon: snap.hasError ? Icons.refresh_rounded : Icons.home_rounded,
                  onAction: snap.hasError
                      ? () => setState(() => _future = _fetch())
                      : () => Navigator.of(context).pushReplacementNamed('/'),
                ),
        );
      },
    );
  }
}

class TechDailyMainShell extends StatefulWidget {
  final ArticleRepository repository;
  final AuthRepository authRepository;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const TechDailyMainShell({
    super.key,
    required this.repository,
    required this.authRepository,
    required this.themeModeNotifier,
  });

  @override
  State<TechDailyMainShell> createState() => _TechDailyMainShellState();
}

class _TechDailyMainShellState extends State<TechDailyMainShell> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};

  Widget _screenFor(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          repository: widget.repository,
          authRepository: widget.authRepository,
          themeModeNotifier: widget.themeModeNotifier,
        );
      case 1:
        return QuickReadsScreen(repository: widget.repository, authRepository: widget.authRepository);
      case 2:
        return CategoryScreen(repository: widget.repository, authRepository: widget.authRepository);
      case 3:
        return SearchScreen(repository: widget.repository, authRepository: widget.authRepository);
      default:
        return SavedScreen(repository: widget.repository, authRepository: widget.authRepository);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          5,
          // Build tabs lazily on first visit, then keep their state.
          (i) => _visited.contains(i) ? _screenFor(i) : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: TechDailyBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (i) => setState(() {
          _currentIndex = i;
          _visited.add(i);
        }),
      ),
    );
  }
}

/// Lets mouse/trackpad users drag lists and swipe Quick Reads on web/desktop.
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
