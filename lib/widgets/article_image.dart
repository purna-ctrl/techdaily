import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/article.dart';
import 'skeleton.dart';

/// Article artwork: network image with a shimmer while loading, and a
/// category-coloured gradient with an icon when there is no image or it fails.
class ArticleImage extends StatelessWidget {
  final Article article;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double iconSize;
  final bool showCategoryLabel;

  const ArticleImage({
    super.key,
    required this.article,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
    this.showCategoryLabel = false,
  });

  static bool hasUsableUrl(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final url = article.imageUrl?.trim();
    final fallback = ArticleArtworkFallback(
      category: article.category,
      iconSize: iconSize,
      showLabel: showCategoryLabel,
    );

    Widget child;
    if (!hasUsableUrl(url)) {
      child = fallback;
    } else {
      child = Image.network(
        url!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        // Many publisher CDNs don't send CORS headers; let the web engine fall
        // back to an <img> element instead of showing a blank box.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (context, img, frame, wasSync) {
          if (wasSync) return img;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: img,
          );
        },
        loadingBuilder: (context, img, progress) {
          if (progress == null) return img;
          return Stack(fit: StackFit.expand, children: [
            const Shimmer(child: SkeletonBox(height: double.infinity, radius: 0)),
            img,
          ]);
        },
        errorBuilder: (context, error, stack) => fallback,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(color: AppTheme.surfaceAltOf(context), child: child),
    );
  }
}

/// Gradient artwork used when a story has no usable image.
class ArticleArtworkFallback extends StatelessWidget {
  final String category;
  final double iconSize;
  final bool showLabel;

  const ArticleArtworkFallback({
    super.key,
    required this.category,
    this.iconSize = 40,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.getCategoryAccent(category, isDark: AppTheme.isDark(context));
    final deep = Color.lerp(c, AppTheme.ink, 0.62)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, deep],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -iconSize * 0.6,
            bottom: -iconSize * 0.6,
            child: Icon(
              AppTheme.categoryIcon(category),
              size: iconSize * 4,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Center(
            child: Icon(
              AppTheme.categoryIcon(category),
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (showLabel && category.isNotEmpty)
            Positioned(
              left: 14,
              top: 14,
              child: Text(
                category,
                style: AppTheme.kicker(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
        ],
      ),
    );
  }
}
