import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/story_questions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../services/v2/story_ask.dart';
import 'jargon.dart';
import 'story_sections.dart';
import 'ui.dart';
import '../../l10n/app_language.dart' show tr;

/// One question section of a story: title + icon + body.
class StorySectionData {
  final String title;
  final IconData icon;
  final Widget body;
  final bool scam;
  final bool highlight;
  const StorySectionData(this.title, this.icon, this.body, {this.scam = false, this.highlight = false});
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  final Color color;
  final IconData? icon;
  const _Bullets({required this.items, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: icon != null
                  ? Icon(icon, size: 18, color: color)
                  : Container(
                      margin: const EdgeInsets.only(top: 5, left: 3, right: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t)),
          ]),
        ),
    ]);
  }
}

class _Fact extends StatelessWidget {
  final String text;
  final Color color;
  const _Fact({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
        child: Text(text, style: const TextStyle(fontSize: 17, height: 1.5)),
      );
}

/// The per-category question sections for [s], empty sections left out.
/// Scam stories: trick, at risk, signs, stay safe, if it happened to you,
/// why it matters.
List<StorySectionData> storySections(Story s, {bool compact = false}) {
  final d = s.display;
  final qs = s.questions;
  final cat = s.categoryInfo;
  final c = cat.tint;
  final out = <StorySectionData>[];
  void text(StoryQuestion q, String t, {bool scam = false, bool highlight = false}) {
    if (t.trim().isEmpty) return;
    out.add(StorySectionData(
      q.label,
      q.icon,
      JargonText(t, accent: scam ? TD.redTint : c, style: highlight ? const TextStyle(fontSize: 17.5, height: 1.5) : null),
      scam: scam,
      highlight: highlight,
    ));
  }

  void todo() {
    if (d.whatToDo.isNotEmpty) {
      final body = switch (qs.todoStyle) {
        ListStyle.steps => TickChecklist(items: d.whatToDo, color: c),
        ListStyle.bullets => _Bullets(items: d.whatToDo, color: cat.color),
        ListStyle.fact => _Fact(text: d.whatToDo.join(' '), color: cat.color),
      };
      out.add(StorySectionData(qs.whatToDo.label, qs.whatToDo.icon, body));
    } else if (d.goodToKnow.isNotEmpty) {
      out.add(StorySectionData(tr(kGoodToKnowLabel), Icons.info_rounded, JargonText(d.goodToKnow, accent: c)));
    }
  }

  final scam = s.scam;
  if (scam != null) {
    text(qs.whatHappened, [d.whatHappened, scam.howItWorks].where((x) => x.isNotEmpty).join(' '), scam: true);
    text(qs.affectsWho, d.affectsWho);
    if (scam.warningSigns.isNotEmpty) {
      out.add(StorySectionData(tr('Spot the signs'), Icons.warning_amber_rounded,
          _Bullets(items: scam.warningSigns, color: TD.focus, icon: Icons.warning_rounded),
          scam: true));
    }
    todo();
    out.add(StorySectionData(
      tr('If it happened to you'),
      Icons.health_and_safety_rounded,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TickChecklist(items: scam.ifTargeted, color: TD.redTint, numbered: true),
        HelplineCallout(compact: compact),
      ]),
      scam: true,
    ));
    text(qs.whatItMeans, d.whatItMeans, highlight: true);
  } else {
    text(qs.whatHappened, d.whatHappened);
    text(qs.affectsWho, d.affectsWho);
    todo();
    text(qs.whatItMeans, d.whatItMeans, highlight: true);
  }
  return out;
}

/// Small grey pill on stories only the rule-based writer has written so far.
class FallbackPill extends StatelessWidget {
  const FallbackPill({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: TD.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TD.glassBorder),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_top_rounded, size: 13, color: TD.muted),
          SizedBox(width: 5),
          Text(kFallbackPill, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TD.muted)),
        ]),
      );
}

/// "In one line" + "Key numbers" (+ the fallback pill) at the top of a story.
class StoryTopBlock extends StatelessWidget {
  final Story story;
  const StoryTopBlock({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final s = story;
    final d = s.display;
    final cat = s.categoryInfo;
    final kicker = AppTheme.kicker(size: 11, color: cat.tint).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (s.isFallback) const Padding(padding: EdgeInsets.only(top: 12), child: FallbackPill()),
      if (d.tldr.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(TD.rMd),
            border: Border.all(color: cat.color.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(tr(kTldrLabel).toUpperCase(), style: kicker)),
            const SizedBox(height: 6),
            Text(d.tldr, style: const TextStyle(fontSize: 18, height: 1.42, fontWeight: FontWeight.w600, color: TD.ink)),
          ]),
        ),
      if (s.keyNumbers.isNotEmpty) ...[
        const SizedBox(height: 14),
        Semantics(header: true, child: Text(tr(kKeyNumbersLabel).toUpperCase(), style: kicker)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in s.keyNumbers)
            Container(
              constraints: const BoxConstraints(minWidth: 92),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: TD.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TD.glassBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(k.value, style: AppTheme.display(18, color: TD.ink, height: 1.15)),
                Text(k.label, style: const TextStyle(fontSize: 12, color: TD.muted)),
              ]),
            ),
        ]),
      ],
    ]);
  }
}

/// One FAQ question as a tappable chip that expands to its answer.
class FaqChip extends StatefulWidget {
  final FaqItem item;
  final Color color;
  const FaqChip({super.key, required this.item, required this.color});

  @override
  State<FaqChip> createState() => _FaqChipState();
}

class _FaqChipState extends State<FaqChip> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _open ? widget.color.withValues(alpha: 0.12) : TD.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _open ? widget.color.withValues(alpha: 0.5) : TD.glassBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    expanded: _open,
                    child: Text(widget.item.q, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TD.ink, height: 1.35)),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.125 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.add_rounded, size: 22, color: widget.color),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topLeft,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Text(widget.item.a, style: const TextStyle(fontSize: 15, height: 1.5, color: TD.ink)),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Ask about this": FAQ chips and (unless [compact]) an "Ask your own
/// question" box answered by [service] (endpoint when set, else on-device).
class AskAboutThis extends StatefulWidget {
  final Story story;
  final bool compact;
  final StoryAskService service;
  final VoidCallback? onOpenSources;
  const AskAboutThis({super.key, required this.story, this.compact = false, this.service = const StoryAskService(), this.onOpenSources});

  @override
  State<AskAboutThis> createState() => _AskAboutThisState();
}

class _AskAboutThisState extends State<AskAboutThis> {
  final _ctrl = TextEditingController();
  AskAnswer? _answer;
  String _asked = '';
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _asked = q;
    });
    final a = await widget.service.ask(widget.story, q);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answer = a;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    final c = s.categoryInfo.tint;
    final chips = [for (final f in s.faq) FaqChip(key: ValueKey('faq-${f.q}'), item: f, color: c)];
    if (widget.compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: chips);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...chips,
      if (chips.isNotEmpty) const SizedBox(height: 6),
      TextField(
        key: const ValueKey('ask-field'),
        controller: _ctrl,
        maxLength: kAskMaxChars,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 15.5, color: TD.ink),
        decoration: InputDecoration(
          hintText: 'Ask your own question…',
          hintStyle: const TextStyle(color: TD.muted),
          counterText: '',
          filled: true,
          fillColor: TD.glass,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: TD.glassBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: TD.glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c)),
          suffixIcon: IconButton(
            key: const ValueKey('ask-send'),
            tooltip: 'Ask',
            onPressed: _submit,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send_rounded, color: c),
          ),
        ),
      ),
      if (_answer != null) ...[
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('ask-answer'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16161C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TD.glassBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_asked, style: const TextStyle(fontSize: 13, color: TD.muted, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Text(_answer!.text, style: const TextStyle(fontSize: 15.5, height: 1.5, color: TD.ink)),
            if (_answer!.unanswered && widget.onOpenSources != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: c, shape: const StadiumBorder(), side: BorderSide(color: c.withValues(alpha: 0.6))),
                  onPressed: widget.onOpenSources,
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: Text(tr('Read the sources')),
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 6),
      Text(
        kAskEndpoint.isEmpty ? 'Answers come from this story only.' : 'Answers use only this story and its sources. Always check the original before acting.',
        style: const TextStyle(fontSize: 12, color: TD.muted),
      ),
    ]);
  }
}
