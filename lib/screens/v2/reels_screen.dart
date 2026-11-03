import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/v3/jargon.dart';
import '../../widgets/v3/story_cards.dart' show metaLine;
import '../../widgets/v3/story_image.dart';
import '../../core/constants/story_questions.dart';
import '../../widgets/v3/story_questions.dart';
import '../../widgets/v3/story_sections.dart';
import '../../widgets/v3/ui.dart';

/// Full-screen vertical "Reels": one story per screen. Image on the top 45%,
/// headline, then the story as swipeable cards (What happened · Does it
/// affect me? · What to do, plus the scam cards), and the action bar.
class ReelsScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  const ReelsScreen({super.key, required this.stories, this.initialIndex = 0});

  static Future<void> open(BuildContext context, List<Story> stories, {int index = 0}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReelsScreen(stories: stories, initialIndex: index)));

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: TD.bg,
      body: Stack(children: [
        PageView.builder(
          key: const ValueKey('reels'),
          controller: _pages,
          scrollDirection: Axis.vertical,
          itemCount: widget.stories.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _Reel(story: widget.stories[i], first: i == 0),
        ),
        Positioned(
          top: pad.top + 8,
          left: 8,
          right: 8,
          child: Row(children: [
            IconButton(
              tooltip: 'Back',
              style: IconButton.styleFrom(backgroundColor: const Color(0x990B0B0F)),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0x990B0B0F), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFFFF8255)),
                const SizedBox(width: 6),
                Text('Reels', style: AppTheme.display(14, color: Colors.white)),
                const SizedBox(width: 8),
                Text('${_index + 1}/${widget.stories.length}', style: AppTheme.numeric(12.5, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Reel extends StatefulWidget {
  final Story story;
  final bool first;
  const _Reel({required this.story, required this.first});

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> {
  final PageController _cards = PageController(viewportFraction: 0.9);
  int _card = 0;

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  List<(String, IconData, Widget, bool)> _sections(Story s, Color c) => [
        if (s.display.tldr.isNotEmpty) (kTldrLabel, Icons.short_text_rounded, JargonText(s.display.tldr, accent: c), false),
        for (final x in storySections(s, compact: true)) (x.title, x.icon, x.body, x.scam),
        if (s.faq.isNotEmpty) (kAskLabel, Icons.forum_rounded, AskAboutThis(story: s, compact: true), false),
      ];

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    final cat = s.categoryInfo;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final sections = _sections(s, cat.tint);
    final frame = s.isScam ? TD.red : cat.color;
    return Container(
      decoration: BoxDecoration(
        color: TD.bg,
        border: s.isScam ? Border.all(color: TD.red, width: 3) : null,
        boxShadow: s.isScam ? [BoxShadow(color: TD.red.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: -6)] : null,
      ),
      child: Column(children: [
        SizedBox(
          height: size.height * 0.45,
          child: Stack(fit: StackFit.expand, children: [
            ScrimmedImage(story: s, showCredit: false),
            if (s.image != null) Positioned(top: pad.top + 64, right: 12, child: ImageCredit(story: s)),
            if (s.isScam)
              Positioned(
                top: pad.top + 64,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: TD.red, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.gpp_maybe_rounded, size: 15, color: TD.bg),
                    const SizedBox(width: 4),
                    Text('SCAM ALERT', style: AppTheme.kicker(size: 11, color: TD.bg).copyWith(fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  CategoryChip(category: cat, glow: true),
                  if (s.developing) const DevelopingPill(),
                ]),
                const SizedBox(height: 8),
                Text(s.headline, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppTheme.display(24, color: Colors.white, height: 1.12)),
                const SizedBox(height: 4),
                Text(metaLine(s), style: const TextStyle(fontSize: 12.5, color: Color(0xFFD2CEC6))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PageView.builder(
            controller: _cards,
            padEnds: false,
            itemCount: sections.length,
            onPageChanged: (i) => setState(() => _card = i),
            itemBuilder: (context, i) {
              final (title, icon, body, scam) = sections[i];
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
                child: SectionCard(
                  margin: EdgeInsets.zero,
                  title: title,
                  icon: icon,
                  color: scam ? TD.red : cat.color,
                  scam: scam,
                  fill: true,
                  child: body,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < sections.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _card ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == _card ? frame : Colors.white24, borderRadius: BorderRadius.circular(3)),
              ),
            const SizedBox(width: 10),
            Text(_card < sections.length - 1 ? 'Swipe cards →' : (widget.first ? 'Swipe up for next story ↑' : 'Next story ↑'),
                style: const TextStyle(fontSize: 12, color: TD.muted)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, pad.bottom + 10),
          child: StoryActionBar(story: s),
        ),
      ]),
    );
  }
}
