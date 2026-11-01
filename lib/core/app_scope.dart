import 'package:flutter/material.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../repositories/auth_repository.dart';

/// Gives any screen access to the app's repositories without threading them
/// through every constructor, and centralises article navigation so every
/// in-app article opens on its shareable `/article/<id>` URL.
class AppScope extends InheritedWidget {
  final ArticleRepository repository;
  final AuthRepository authRepository;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const AppScope({
    super.key,
    required this.repository,
    required this.authRepository,
    required this.themeModeNotifier,
    required super.child,
  });

  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  static AppScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository ||
      authRepository != oldWidget.authRepository ||
      themeModeNotifier != oldWidget.themeModeNotifier;
}

/// Route name for an article deep link.
String articleRoutePath(String id) => '/article/${Uri.encodeComponent(id)}';

/// Parses `/article/<id>` (also tolerates a trailing slash or query string).
String? articleIdFromRoute(String? name) {
  if (name == null) return null;
  final uri = Uri.tryParse(name);
  if (uri == null) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length == 2 && segments.first == 'article') {
    return segments[1];
  }
  return null;
}

/// Opens [article] on its deep-link route (the URL bar updates on web).
Future<void> openArticle(BuildContext context, Article article) {
  return Navigator.of(context).pushNamed(articleRoutePath(article.id), arguments: article);
}
