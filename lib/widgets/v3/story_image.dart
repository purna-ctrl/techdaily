import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../models/story.dart';
import '../v2/story_parts.dart' show openExternal;
import 'category_art.dart';
import 'ui.dart';

/// A story's publisher image over its category artwork.
///
/// * The art is always painted first, so a slow, missing or broken image
///   never shows a blank box (the error builder keeps the art).
/// * Web: publisher CDNs rarely send CORS headers, so images go through the
///   `kImageProxy` pass-through and are drawn in the canvas. Plain `<img>`
///   platform views (the old way) made scrolling lag.
/// * [cacheWidth] keeps decoded bitmaps small on mobile.
class StoryImageView extends StatelessWidget {
  final Story story;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final Alignment artAlignment;

  /// Vertical parallax shift in logical pixels (hero image).
  final double parallax;
  const StoryImageView({
    super.key,
    required this.story,
    this.borderRadius,
    this.cacheWidth,
    this.artAlignment = Alignment.center,
    this.parallax = 0,
  });

  @override
  Widget build(BuildContext context) {
    final img = story.image;
    final art = CategoryArtwork(categoryId: story.category, alignment: artAlignment);
    Widget child;
    if (img == null) {
      child = art;
    } else {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
      child = Stack(fit: StackFit.expand, children: [
        art,
        Transform.translate(
          offset: Offset(0, parallax),
          child: Transform.scale(
            scale: parallax == 0 ? 1 : 1.12,
            child: Image.network(
              kIsWeb ? webImageUrl(img.url) : img.url,
              key: ValueKey(img.url),
              fit: BoxFit.cover,
              // Hotlinked: never re-hosted. Errors fall back to the art below.
              // Web: through the CORS pass-through it draws in the canvas (smooth
              // scrolling); `<img>` only if that fails and there is no proxy.
              webHtmlElementStrategy: kImageProxy.isEmpty ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
              cacheWidth: cacheWidth == null ? null : (cacheWidth! * dpr).round(),
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              semanticLabel: null,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, sync) {
                if (sync || frame != null) return child;
                return const SizedBox.expand();
              },
              errorBuilder: (context, error, stack) => const SizedBox.expand(),
            ),
          ),
        ),
      ]);
    }
    if (borderRadius != null) child = ClipRRect(borderRadius: borderRadius!, child: child);
    return child;
  }
}

/// Visible "Image: <Source>" credit that opens the source article.
class ImageCredit extends StatelessWidget {
  final Story story;
  final bool compact;
  const ImageCredit({super.key, required this.story, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final img = story.image;
    if (img == null) return const SizedBox.shrink();
    return Semantics(
      link: true,
      label: 'Image credit: ${img.sourceName}. Opens the source article.',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xD10B0B0F),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => openExternal(context, img.sourceUrl),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 120 : 200),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Image: '),
                  TextSpan(text: img.sourceName, style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Colors.white70)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 10 : 11.5, color: const Color(0xFFEDEAE3), height: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image + scrim + credit, for heroes and feature cards.
class ScrimmedImage extends StatelessWidget {
  final Story story;
  final double parallax;
  final bool showCredit;
  final bool compactCredit;
  final Gradient scrim;
  const ScrimmedImage({
    super.key,
    required this.story,
    this.parallax = 0,
    this.showCredit = true,
    this.compactCredit = false,
    this.scrim = TD.imageScrim,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      StoryImageView(story: story, parallax: parallax, artAlignment: Alignment.centerRight),
      IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: scrim))),
      if (showCredit && story.image != null)
        Positioned(top: 10, right: 10, child: ImageCredit(story: story, compact: compactCredit)),
    ]);
  }
}
