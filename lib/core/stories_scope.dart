import 'package:flutter/material.dart';

import '../models/story.dart';
import '../repositories/auth_repository.dart';
import '../repositories/story_repository.dart';
import '../services/v2/daily_streak.dart';
import '../services/v2/newsletter_service.dart';
import '../services/v2/scam_game.dart';
import '../services/v2/story_translator.dart';
import '../services/v2/saved_stories.dart';
import '../services/v2/topic_prefs.dart';

/// Gives every v2 screen the story repository, saved stories, topic filter,
/// newsletter and auth without threading them through constructors.
class StoriesScope extends InheritedWidget {
  final StoryRepository stories;
  final SavedStoriesController saved;
  final TopicPrefs topics;
  final NewsletterService newsletter;
  final AuthRepository auth;

  /// "Scam or Not?" answers + streak, and the Today in 5 "caught up" streak.
  final ScamGameController scamGame;
  final CaughtUpStreak caughtUp;

  /// Telugu / Hindi story translation (null in older tests: stories stay English).
  final StoryTranslator? translator;

  const StoriesScope({
    super.key,
    required this.stories,
    required this.saved,
    required this.topics,
    required this.newsletter,
    required this.auth,
    required this.scamGame,
    required this.caughtUp,
    this.translator,
    required super.child,
  });

  /// The story translator, or one that always shows English.
  StoryTranslator get translations => translator ?? _englishOnly;

  static StoriesScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<StoriesScope>();
    assert(s != null, 'StoriesScope not found');
    return s!;
  }

  @override
  bool updateShouldNotify(StoriesScope old) =>
      stories != old.stories || saved != old.saved || topics != old.topics || newsletter != old.newsletter || auth != old.auth || scamGame != old.scamGame || caughtUp != old.caughtUp || translator != old.translator;
}

final StoryTranslator _englishOnly = StoryTranslator();

/// In-app route for a story. `/story/<slug>/` (no `/app`) is the static,
/// pre-rendered page that Hosting serves; the app uses `/app/story/<slug>`.
String storyRoutePath(String slug) => '/app/story/${Uri.encodeComponent(slug)}';

Future<void> openStory(BuildContext context, Story story) =>
    Navigator.of(context).pushNamed(storyRoutePath(story.slug), arguments: story.original);

Future<void> openStorySlug(BuildContext context, String slug) =>
    Navigator.of(context).pushNamed(storyRoutePath(slug));

enum AppRouteKind { home, story, category, saved, search, settings, newsletter, about, scamCheck, legacyArticle, unknown }

/// Parsed app route. Accepts `/app/...` and bare paths (`/story/x`, `/saved`).
class AppRoute {
  final AppRouteKind kind;
  final String? param;
  final Map<String, String> query;

  const AppRoute(this.kind, [this.param, this.query = const {}]);

  static AppRoute parse(String? name) {
    final uri = Uri.tryParse(name ?? '/') ?? Uri.parse('/');
    var seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.isNotEmpty && seg.first == 'app') seg = seg.sublist(1);
    final q = uri.queryParameters;
    if (seg.isEmpty) return AppRoute(AppRouteKind.home, null, q);
    switch (seg.first) {
      case 'story':
        return seg.length == 2 ? AppRoute(AppRouteKind.story, seg[1], q) : const AppRoute(AppRouteKind.unknown);
      case 'c':
        return seg.length == 2 ? AppRoute(AppRouteKind.category, seg[1], q) : const AppRoute(AppRouteKind.unknown);
      case 'article':
        return seg.length == 2 ? AppRoute(AppRouteKind.legacyArticle, seg[1], q) : const AppRoute(AppRouteKind.unknown);
      case 'saved':
        return const AppRoute(AppRouteKind.saved);
      case 'search':
        return AppRoute(AppRouteKind.search, q['q'], q);
      case 'settings':
        return const AppRoute(AppRouteKind.settings);
      case 'newsletter':
        return AppRoute(AppRouteKind.newsletter, q['email'], q);
      case 'about':
        return const AppRoute(AppRouteKind.about);
      case 'scam-check':
        return AppRoute(AppRouteKind.scamCheck, q['text'], q);
    }
    return const AppRoute(AppRouteKind.unknown);
  }
}
