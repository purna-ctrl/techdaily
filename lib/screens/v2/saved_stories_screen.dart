import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/story_widgets.dart' show FriendlyState;
import '../../widgets/v2/story_parts.dart';
import '../auth_screen.dart';

class SavedStoriesScreen extends StatelessWidget {
  const SavedStoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Saved', style: AppTheme.display(20, color: theme.colorScheme.onSurface))),
      body: ListenableBuilder(
        listenable: scope.saved,
        builder: (context, _) {
          final list = scope.saved.stories;
          final guestBanner = scope.saved.isGuest
              ? Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Row(children: [
                    Icon(Icons.phone_android_rounded, color: AppTheme.accentOf(context)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Saved on this device. Sign in (optional) to keep them on all your devices.')),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AuthScreen(authRepository: scope.auth),
                      )),
                      child: const Text('Sign in'),
                    ),
                  ]),
                )
              : null;
          if (list.isEmpty) {
            return ListView(padding: const EdgeInsets.all(12), children: [
              ?guestBanner,
              const SizedBox(height: 30),
              const FriendlyState(
                icon: Icons.bookmark_border_rounded,
                title: 'Nothing saved yet',
                message: 'Tap the bookmark on any story to keep it here.',
              ),
            ]);
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                itemCount: list.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ?guestBanner,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${list.length} ${list.length == 1 ? 'story' : 'stories'}',
                            style: TextStyle(color: AppTheme.mutedOf(context))),
                      ),
                    ]);
                  }
                  return StoryCard(story: list[i - 1]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
