import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config/app_config.dart';
import '../models/article.dart';

/// Builds share payloads and shares them through the OS share sheet
/// (share_plus). On web, if the Web Share API is unavailable, the text is
/// copied to the clipboard and a snackbar confirms it.
class ShareService {
  const ShareService();

  /// Deep link that opens this article inside TechDaily.
  static String appLink(Article article) =>
      '$kSiteUrl/article/${Uri.encodeComponent(article.id)}';

  /// Text shared: headline, the in-app link and the exact original link.
  static String shareText(Article article) {
    final buffer = StringBuffer(article.title.trim())
      ..write('\n\n')
      ..write('Read on TechDaily: ${appLink(article)}');
    final source = article.sourceUrl.trim();
    if (source.isNotEmpty) {
      buffer.write('\nOriginal: $source');
    }
    return buffer.toString();
  }

  Future<void> shareArticle(BuildContext context, Article article) async {
    final text = shareText(article);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      final result = await SharePlus.instance.share(ShareParams(
        text: text,
        subject: article.title,
        title: article.title,
        sharePositionOrigin: origin,
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ));
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (e) {
      debugPrint('Share sheet unavailable, falling back to clipboard: $e');
    }

    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(kIsWeb
            ? 'Link copied — paste it anywhere to share'
            : 'Link copied to clipboard'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
