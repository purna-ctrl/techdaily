import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import 'story_image.dart';
import 'language_widgets.dart' show BriefListenButton;
import 'ui.dart';
import '../../l10n/app_language.dart' show tr;

/// Stories viewed in the full-screen viewer this session (rings turn grey).
final ValueNotifier<Set<String>> viewedStoryIds = ValueNotifier<Set<String>>(<String>{});

void markStoryViewed(String id) {
  if (viewedStoryIds.value.contains(id)) return;
  viewedStoryIds.value = {...viewedStoryIds.value, id};
}

/// "Today in 5" as Instagram-style rings: circular image, category-coloured
/// gradient ring (grey once seen), number + short label below.
class StoryRings extends StatelessWidget {
  final List<Story> stories;
  final void Function(int index) onOpen;
  final int streak;
  final bool caughtUp;
  const StoryRings({super.key, required this.stories, required this.onOpen, this.streak = 0, this.caughtUp = false});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(children: [
          Semantics(header: true, child: Text(tr('Today in {n}', {'n': stories.length}), style: AppTheme.display(20, color: TD.ink))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(caughtUp ? tr('· all caught up') : tr('· tap to watch'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: TD.muted)),
          ),
          const SizedBox(width: 6),
          BriefListenButton(stories: stories),
          if (streak > 0) const SizedBox(width: 8),
          if (streak > 0)
            Row(children: [
              const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFB061)),
              const SizedBox(width: 2),
              Text(streak == 1 ? tr('1 day') : tr('{n} days', {'n': streak}), style: AppTheme.numeric(12.5, color: const Color(0xFFFFB061))),
            ]),
        ]),
      ),
      SizedBox(
        height: 112,
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: viewedStoryIds,
          builder: (context, viewed, _) => ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => RepaintBoundary(
              child: _Ring(
                key: ValueKey('ring-$i'),
                story: stories[i],
                number: i + 1,
                seen: viewed.contains(stories[i].id),
                onTap: () => onOpen(i),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Ring extends StatelessWidget {
  final Story story;
  final int number;
  final bool seen;
  final VoidCallback onTap;
  const _Ring({super.key, required this.story, required this.number, required this.seen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = story.categoryInfo;
    return Semantics(
      button: true,
      label: 'Story $number: ${story.headline}${seen ? ' (seen)' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: seen
                      ? const LinearGradient(colors: [Color(0xFF4A4A55), Color(0xFF34343D)])
                      : SweepGradient(colors: [cat.color, cat.tint, Colors.white, cat.color]),
                  boxShadow: seen || TD.cheapFx ? null : [BoxShadow(color: cat.color.withValues(alpha: 0.45), blurRadius: 14)],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(color: TD.bg, shape: BoxShape.circle),
                  child: ClipOval(child: StoryImageView(story: story, cacheWidth: 70)),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle, border: Border.all(color: TD.bg, width: 2)),
                  child: Text('$number', style: AppTheme.numeric(12, color: TD.bg, family: AppTheme.displayFont)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(cat.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: seen ? TD.muted : TD.ink)),
          ]),
        ),
      ),
    );
  }
}
