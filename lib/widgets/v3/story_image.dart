import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
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

  /// Vertical parallax shift in logical pixels (hero image). Only the image's
  /// transform listens to it.
  final ValueListenable<double>? parallax;
  const StoryImageView({
    super.key,
    required this.story,
    this.borderRadius,
    this.cacheWidth,
    this.artAlignment = Alignment.center,
    this.parallax,
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
      final p = parallax;
      Widget image(int? decodeWidth) => Image.network(
              kIsWeb ? webImageUrl(img.url) : img.url,
              key: ValueKey(img.url),
              fit: BoxFit.cover,
              // Hotlinked: never re-hosted. Errors fall back to the art below.
              // Web: through the CORS pass-through it draws in the canvas (smooth
              // scrolling); `<img>` only if that fails and there is no proxy.
              webHtmlElementStrategy: kImageProxy.isEmpty ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
              cacheWidth: decodeWidth,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              semanticLabel: null,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, sync) {
                if (sync || frame != null) return child;
                return const SizedBox.expand();
              },
              errorBuilder: (context, error, stack) => const SizedBox.expand(),
            );
      // Decode at the size it is drawn (x device pixel ratio), never the
      // publisher's full-size original. Parallax draws the image 12% larger.
      final img0 = cacheWidth != null
          ? image((cacheWidth! * dpr).round())
          : LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
              return image(_bucket(w * dpr * (p == null ? 1 : 1.12)));
            });
      child = Stack(fit: StackFit.expand, children: [
        art,
        if (p == null)
          img0
        else
          ValueListenableBuilder<double>(
            valueListenable: p,
            child: Transform.scale(scale: 1.12, child: img0),
            builder: (context, dy, scaled) => Transform.translate(offset: Offset(0, dy), child: scaled),
          ),
      ]);
    }
    if (borderRadius != null) child = ClipRRect(borderRadius: borderRadius!, child: child);
    return child;
  }
}

/// Rounds a decode width up to a 160 px step so small layout changes reuse
/// the same decoded image.
int _bucket(double px) => ((px / 160).ceil() * 160).clamp(160, 2400).toInt();

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
  final ValueListenable<double>? parallax;
  final bool showCredit;
  final bool compactCredit;
  final Gradient scrim;
  const ScrimmedImage({
    super.key,
    required this.story,
    this.parallax,
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
