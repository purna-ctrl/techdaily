import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/jargon.dart';
import '../../core/theme/app_theme.dart';
import 'ui.dart';

/// Bottom sheet: the word, its meaning in simple words, and an example.
Future<void> showJargonSheet(BuildContext context, JargonEntry e, {Color accent = const Color(0xFFFF8255)}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: TD.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.menu_book_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(e.term, style: AppTheme.display(24, color: TD.ink))),
          ]),
          const SizedBox(height: 4),
          Text('IN SIMPLE WORDS', style: AppTheme.kicker(size: 11, color: accent)),
          const SizedBox(height: 10),
          Text(e.meaning, style: const TextStyle(fontSize: 17, height: 1.55, color: TD.ink)),
          if (e.example != null) ...[
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(14),
              radius: TD.rSm,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text(e.example!, style: const TextStyle(fontSize: 15, height: 1.5, color: TD.muted))),
              ]),
            ),
          ],
        ]),
      ),
    ),
  );
}

/// Body text with jargon words underlined; tapping one opens [showJargonSheet].
class JargonText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color accent;
  final int? maxLines;
  const JargonText(this.text, {super.key, this.style, this.accent = const Color(0xFFFF8255), this.maxLines});

  @override
  State<JargonText> createState() => _JargonTextState();
}

class _JargonTextState extends State<JargonText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final t = widget.text;
    final hits = findJargon(t);
    final spans = <InlineSpan>[];
    var i = 0;
    for (final (s, e, entry) in hits) {
      if (s > i) spans.add(TextSpan(text: t.substring(i, s)));
      final r = TapGestureRecognizer()..onTap = () => showJargonSheet(context, entry, accent: widget.accent);
      _recognizers.add(r);
      spans.add(TextSpan(
        text: t.substring(s, e),
        recognizer: r,
        semanticsLabel: '${t.substring(s, e)} (tap for meaning)',
        style: TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: widget.accent,
          decorationThickness: 2,
          color: widget.accent,
          fontWeight: FontWeight.w600,
        ),
      ));
      i = e;
    }
    if (i < t.length) spans.add(TextSpan(text: t.substring(i)));
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// "Words in this story" chips.
class JargonChips extends StatelessWidget {
  final List<JargonEntry> entries;
  final Color accent;
  const JargonChips({super.key, required this.entries, this.accent = const Color(0xFFFF8255)});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.menu_book_rounded, size: 16, color: accent),
        const SizedBox(width: 6),
        Text('Tap a word to understand it', style: AppTheme.kicker(size: 11, color: TD.muted)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in entries)
          ActionChip(
            key: ValueKey('jargon-${e.term}'),
            label: Text(e.term),
            avatar: Icon(Icons.help_outline_rounded, size: 16, color: accent),
            backgroundColor: accent.withValues(alpha: 0.1),
            side: BorderSide(color: accent.withValues(alpha: 0.45)),
            labelStyle: const TextStyle(color: TD.ink, fontWeight: FontWeight.w600, fontSize: 13.5),
            onPressed: () => showJargonSheet(context, e, accent: accent),
          ),
      ]),
    ]);
  }
}
