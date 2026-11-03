import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/story.dart';
import 'story_image.dart';
import 'story_sections.dart' show toggleSave;
import 'ui.dart';

String metaLine(Story s) {
  final names = s.sourceNames;
  final src = names.isEmpty ? '' : (names.length > 1 ? '${names.first} +${names.length - 1}' : names.first);
  return '${AppDateUtils.formatRelativeTime(s.publishedAt)}${src.isEmpty ? '' : ' · $src'}';
}

/// One-liner for cards: "what it means for you" (skipped for rule-based text).
String? oneLiner(Story s) => s.isFallback || s.whatItMeans.trim().isEmpty ? null : s.whatItMeans;

class SaveIconButton extends StatelessWidget {
  final Story story;
  final bool onImage;
  const SaveIconButton({super.key, required this.story, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    return ListenableBuilder(
      listenable: scope.saved,
      builder: (context, _) {
        final saved = scope.saved.isSaved(story.id);
        final btn = IconButton(
          key: ValueKey('save-${story.id}'),
          tooltip: saved ? 'Remove from saved' : 'Save story',
          onPressed: () => toggleSave(context, story),
          icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? story.categoryInfo.tint : TD.ink),
        );
        if (!onImage) return btn;
        return DecoratedBox(decoration: const BoxDecoration(color: Color(0xB30B0B0F), shape: BoxShape.circle), child: btn);
      },
    );
  }
}

/// #1 story: full-bleed image, scrim, chip, big headline, parallax.
class HeroStoryCard extends StatelessWidget {
  final Story story;
  final double parallax;
  final VoidCallback onTap;
  const HeroStoryCard({super.key, required this.story, required this.onTap, this.parallax = 0});

  @override
  Widget build(BuildContext context) {
    final cat = story.categoryInfo;
    final line = oneLiner(story);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Pressable(
        onTap: onTap,
        radius: TD.rXl,
        semanticLabel: 'Top story: ${story.headline}',
        child: Container(
          height: 460,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TD.rXl),
            border: Border.all(color: TD.glassBorder),
            boxShadow: [BoxShadow(color: cat.color.withValues(alpha: 0.32), blurRadius: 50, spreadRadius: -16, offset: const Offset(0, 24))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TD.rXl),
            child: Stack(fit: StackFit.expand, children: [
              ScrimmedImage(story: story, parallax: parallax),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    CategoryChip(category: cat, glow: true),
                    if (story.developing) const DevelopingPill(),
                  ]),
                  const SizedBox(height: 10),
                  Text(story.headline,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(29, color: Colors.white, height: 1.08).copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 14)])),
                  if (line != null) ...[
                    const SizedBox(height: 8),
                    Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, height: 1.4, color: Color(0xFFDAD6CE))),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text(metaLine(story), style: const TextStyle(fontSize: 13, color: Color(0xFFD2CEC6)))),
                    SaveIconButton(story: story, onImage: true),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Rail card: image on top, colour chip, headline, "what it means" one-liner.
class RailCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final double width;
  const RailCard({super.key, required this.story, required this.onTap, this.width = 256});

  @override
  Widget build(BuildContext context) {
    final cat = story.categoryInfo;
    final line = oneLiner(story);
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        radius: TD.rMd + 2,
        semanticLabel: story.headline,
        child: Container(
          decoration: BoxDecoration(
            color: TD.surface,
            borderRadius: BorderRadius.circular(TD.rMd + 2),
            border: Border.all(color: TD.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: width * 0.6,
              child: Stack(fit: StackFit.expand, children: [
                StoryImageView(story: story, cacheWidth: width.round()),
                Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 3, color: cat.color)),
                Positioned(left: 10, bottom: 12, child: CategoryChip(category: cat, small: true)),
                if (story.image != null) Positioned(top: 8, right: 8, child: ImageCredit(story: story, compact: true)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(story.headline, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTheme.display(16.5, color: TD.ink, height: 1.22)),
                  const SizedBox(height: 6),
                  if (line != null)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: cat.tint)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4, color: TD.muted))),
                    ]),
                  const Spacer(),
                  Row(children: [
                    if (story.developing) ...[const DevelopingPill(small: true), const SizedBox(width: 6)],
                    Expanded(child: Text(metaLine(story), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: TD.muted))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Compact list card: text left, square thumbnail right.
class CompactStoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback? onTap;
  const CompactStoryCard({super.key, required this.story, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = story.categoryInfo;
    final line = oneLiner(story);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap ?? () => openStory(context, story),
        radius: TD.rMd,
        semanticLabel: story.headline,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
          decoration: BoxDecoration(
            color: TD.surface,
            borderRadius: BorderRadius.circular(TD.rMd),
            border: Border.all(color: TD.glassBorder),
          ),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    CategoryChip(category: cat, small: true),
                    if (story.developing) const DevelopingPill(small: true),
                  ]),
                  const SizedBox(height: 7),
                  Text(story.headline, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTheme.display(16.5, color: TD.ink, height: 1.22)),
                  if (line != null) ...[
                    const SizedBox(height: 4),
                    Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4, color: TD.muted)),
                  ],
                ]),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                height: 96,
                child: StoryImageView(story: story, borderRadius: BorderRadius.circular(16), cacheWidth: 96),
              ),
            ]),
            Row(children: [
              Expanded(
                child: Text(
                  story.image == null ? metaLine(story) : '${metaLine(story)} · Image: ${story.image!.sourceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: TD.muted),
                ),
              ),
              SaveIconButton(story: story),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Loading placeholder for the home screen.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), children: [
            for (var i = 0; i < 5; i++)
              const Padding(padding: EdgeInsets.only(right: 12), child: Shimmer(width: 64, height: 64, radius: 40)),
          ]),
        ),
        const Shimmer(height: 420, radius: TD.rXl),
        const SizedBox(height: 16),
        const Shimmer(height: 150, radius: TD.rLg),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Shimmer(height: 220)),
          SizedBox(width: 12),
          Expanded(child: Shimmer(height: 220)),
        ]),
      ],
    );
  }
}
