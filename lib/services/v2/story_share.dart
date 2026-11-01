import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/story.dart';

/// Sharing a story: WhatsApp first, then the system share sheet, then copy.
class StoryShare {
  const StoryShare();

  static String shareText(Story s) => '${s.headline}\n\n${s.webUrl}';

  /// `https://wa.me/?text=<headline + story URL>` — opens WhatsApp (app or web).
  static Uri whatsappUri(Story s) => Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText(s))}');

  Future<void> whatsapp(BuildContext context, Story s) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await launchUrl(whatsappUri(s), mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('WhatsApp share failed: $e');
    }
    await Clipboard.setData(ClipboardData(text: shareText(s)));
    messenger?.showSnackBar(const SnackBar(content: Text('Couldn’t open WhatsApp — link copied instead')));
  }

  Future<void> system(BuildContext context, Story s) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      final r = await SharePlus.instance.share(ShareParams(
        text: shareText(s),
        subject: s.headline,
        title: s.headline,
        sharePositionOrigin: origin,
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ));
      if (r.status != ShareResultStatus.unavailable) return;
    } catch (e) {
      debugPrint('Share sheet unavailable: $e');
    }
    await Clipboard.setData(ClipboardData(text: s.webUrl));
    messenger?.showSnackBar(const SnackBar(content: Text('Link copied — paste it anywhere to share')));
  }

  Future<void> copyLink(BuildContext context, Story s) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: s.webUrl));
    messenger?.showSnackBar(const SnackBar(content: Text('Link copied')));
  }
}
