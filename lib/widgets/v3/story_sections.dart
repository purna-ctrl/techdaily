import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../services/text_to_speech_service.dart';
import '../../services/v2/story_share.dart';
import '../v2/story_parts.dart' show openExternal, istTime;
import 'jargon.dart';
import 'ui.dart';

/// Card section ("What happened", "Does it affect me?" …) with an icon bubble.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool scam;
  final bool highlight;
  final EdgeInsetsGeometry margin;

  /// Fill the available height and scroll the body inside (Reels cards).
  final bool fill;
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.scam = false,
    this.highlight = false,
    this.margin = const EdgeInsets.only(top: 12),
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = scam ? TD.redTint : color;
    final body = DefaultTextStyle.merge(style: const TextStyle(fontSize: 16, height: 1.55, color: TD.ink), child: child);
    final card = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: (scam ? TD.red : color).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 19, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(child: Semantics(header: true, child: Text(title, style: AppTheme.display(18, color: scam ? TD.redTint : TD.ink, height: 1.2)))),
      ]),
      const SizedBox(height: 10),
      if (fill) Expanded(child: SingleChildScrollView(child: body)) else body,
    ]);
    if (highlight) {
      return Container(
        margin: margin,
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TD.rLg),
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.15), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: -10, offset: const Offset(0, 14))],
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF16161C), borderRadius: BorderRadius.circular(TD.rLg - 1.6)),
          child: card,
        ),
      );
    }
    return GlassCard(
      margin: margin,
      tint: scam ? TD.red : null,
      borderColor: scam ? TD.red.withValues(alpha: 0.55) : null,
      glow: scam ? TD.red : null,
      child: card,
    );
  }
}

/// "What to do" as a checklist whose ticks animate in one after another; tap
/// an item to tick it off yourself.
class TickChecklist extends StatefulWidget {
  final List<String> items;
  final Color color;
  final bool numbered;
  const TickChecklist({super.key, required this.items, required this.color, this.numbered = false});

  @override
  State<TickChecklist> createState() => _TickChecklistState();
}

class _TickChecklistState extends State<TickChecklist> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final motion = Motion.enabled(context);
    return Column(children: [
      for (var i = 0; i < widget.items.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: motion ? 0 : 1, end: 1),
                duration: Duration(milliseconds: 380 + i * 220),
                curve: Curves.easeOutBack,
                builder: (context, t, _) {
                  final checked = _done.contains(i);
                  return Transform.scale(
                    scale: 0.6 + 0.4 * t.clamp(0, 1.2),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: checked ? widget.color : widget.color.withValues(alpha: 0.18 + 0.1 * t.clamp(0, 1)),
                        border: Border.all(color: widget.color, width: 1.6),
                      ),
                      child: widget.numbered && !checked
                          ? Center(child: Text('${i + 1}', style: AppTheme.numeric(13, color: widget.color, family: AppTheme.displayFont)))
                          : Icon(Icons.check_rounded, size: 17, color: checked ? TD.bg : widget.color.withValues(alpha: t.clamp(0, 1).toDouble())),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: _done.contains(i) ? TD.muted : TD.ink,
                      decoration: _done.contains(i) ? TextDecoration.lineThrough : null,
                      decorationColor: TD.muted,
                    ),
                    child: Text(widget.items[i]),
                  ),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  const _Bullets({required this.items, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Text(t)),
          ]),
        ),
    ]);
  }
}

/// Helpline call-out: 1930 + cybercrime.gov.in.
class HelplineCallout extends StatelessWidget {
  final bool compact;
  const HelplineCallout({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x8C0B0B0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TD.red.withValues(alpha: 0.5)),
      ),
      child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(
          key: const ValueKey('call-1930'),
          style: FilledButton.styleFrom(backgroundColor: TD.red, foregroundColor: TD.bg, shape: const StadiumBorder()),
          onPressed: () => openExternal(context, 'tel:1930'),
          icon: const Icon(Icons.call_rounded, size: 18),
          label: const Text('Call 1930'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: TD.ink, shape: const StadiumBorder(), side: const BorderSide(color: TD.glassBorder)),
          onPressed: () => openExternal(context, 'https://cybercrime.gov.in'),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('cybercrime.gov.in'),
        ),
        if (!compact)
          const Text('India’s cyber-crime helpline. Report quickly — money can sometimes be frozen.',
              style: TextStyle(fontSize: 13, color: TD.muted, height: 1.4)),
      ]),
    );
  }
}

/// The scam template: how the trick works, warning signs, if targeted.
class ScamSections extends StatelessWidget {
  final ScamInfo scam;
  const ScamSections({super.key, required this.scam});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SectionCard(title: 'How the trick works', icon: Icons.phishing_rounded, color: TD.red, scam: true, child: JargonText(scam.howItWorks, accent: TD.redTint)),
      SectionCard(
        title: 'Warning signs',
        icon: Icons.warning_amber_rounded,
        color: TD.red,
        scam: true,
        child: _Bullets(items: scam.warningSigns, icon: Icons.warning_rounded, color: TD.focus),
      ),
      SectionCard(
        title: 'What to do if you’re targeted',
        icon: Icons.health_and_safety_rounded,
        color: TD.red,
        scam: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TickChecklist(items: scam.ifTargeted, color: TD.redTint, numbered: true),
          const HelplineCallout(),
          if (scam.advisoryUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: TD.redTint, shape: const StadiumBorder(), side: BorderSide(color: TD.red.withValues(alpha: 0.6))),
                onPressed: () => openExternal(context, scam.advisoryUrl!),
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: const Text('Official advisory'),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Bottom sheet with every original report.
Future<void> showSourcesSheet(BuildContext context, Story story) {
  final cat = story.categoryInfo;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: TD.surface,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text(story.sources.length > 1 ? 'Read the originals' : 'Read the original', style: AppTheme.display(22, color: TD.ink)),
          const SizedBox(height: 4),
          const Text('TechDaily explains the news in simple words. Always check the original before acting on money or security advice.',
              style: TextStyle(fontSize: 13.5, color: TD.muted, height: 1.45)),
          const SizedBox(height: 10),
          for (final s in story.sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cat.color.withValues(alpha: 0.18),
                child: Text(s.name.isEmpty ? '?' : s.name.characters.first, style: TextStyle(color: cat.tint, fontWeight: FontWeight.w800)),
              ),
              title: Text(s.name),
              subtitle: Text('${s.title.isEmpty ? s.url : s.title}\n${istTime(s.publishedAt)}', maxLines: 3, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Icon(Icons.open_in_new_rounded, color: cat.tint),
              onTap: () => openExternal(ctx, s.url),
            ),
        ]),
      ),
    ),
  );
}

/// Listen (text-to-speech) toggle.
class ListenButton extends StatefulWidget {
  final Story story;
  final bool iconOnly;
  const ListenButton({super.key, required this.story, this.iconOnly = false});

  @override
  State<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<ListenButton> {
  ITextToSpeechService? _tts;

  ITextToSpeechService get tts => _tts ??= (FlutterTtsService()..addListener(_changed));

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts?.removeListener(_changed);
    _tts?.dispose();
    super.dispose();
  }

  String _script(Story s) => [
        s.headline,
        'What happened. ${s.whatHappened}',
        'Does it affect me? ${s.affectsWho}',
        if (s.scam != null) 'Warning signs. ${s.scam!.warningSigns.join('. ')}',
        'What to do. ${s.whatToDo.join('. ')}',
        'What this means for you. ${s.whatItMeans}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final playing = _tts?.state == TtsPlaybackState.playing;
    final label = playing ? 'Stop' : 'Listen';
    final icon = Icon(playing ? Icons.stop_circle_rounded : Icons.headphones_rounded);
    void onTap() => playing ? tts.stop() : tts.speak(_script(widget.story));
    if (widget.iconOnly) return IconButton(tooltip: playing ? 'Stop listening' : 'Listen to this story', onPressed: onTap, icon: icon);
    return _BarButton(icon: icon, label: label, onTap: onTap, tooltip: playing ? 'Stop listening' : 'Listen to this story');
  }
}

class _BarButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  const _BarButton({super.key, required this.icon, required this.label, required this.onTap, this.tooltip, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              IconTheme.merge(data: IconThemeData(color: color ?? TD.ink, size: 24), child: icon),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color ?? TD.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Story action bar: WhatsApp share (first, green), Save, Listen, Sources.
class StoryActionBar extends StatelessWidget {
  final Story story;
  final bool glass;
  const StoryActionBar({super.key, required this.story, this.glass = true});

  @override
  Widget build(BuildContext context) {
    final scope = StoriesScope.of(context);
    const share = StoryShare();
    return ListenableBuilder(
      listenable: scope.saved,
      builder: (context, _) {
        final saved = scope.saved.isSaved(story.id);
        final cat = story.categoryInfo;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: glass
              ? BoxDecoration(
                  color: const Color(0xE6141419),
                  borderRadius: BorderRadius.circular(TD.rLg),
                  border: Border.all(color: TD.glassBorder),
                  boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))],
                )
              : null,
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: ValueKey('wa-${story.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: TD.whatsapp,
                  foregroundColor: TD.bg,
                  minimumSize: const Size(0, 50),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                onPressed: () => share.whatsapp(context, story),
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('WhatsApp'),
              ),
            ),
            const SizedBox(width: 4),
            _BarButton(
              key: ValueKey('save-${story.id}'),
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              label: saved ? 'Saved' : 'Save',
              color: saved ? cat.tint : null,
              tooltip: saved ? 'Remove from saved' : 'Save story',
              onTap: () => toggleSave(context, story),
            ),
            ListenButton(story: story),
            _BarButton(
              icon: const Icon(Icons.article_outlined),
              label: 'Sources',
              tooltip: 'Read original sources',
              onTap: () => showSourcesSheet(context, story),
            ),
          ]),
        );
      },
    );
  }
}

Future<void> toggleSave(BuildContext context, Story story) async {
  final scope = StoriesScope.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final now = await scope.saved.toggle(story);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(now ? (scope.saved.isGuest ? 'Saved on this device' : 'Saved to your account') : 'Removed from saved'),
    duration: const Duration(seconds: 2),
  ));
}

/// Category colour for a story id (helper for widgets that only have the id).
Color categoryColor(String id) => storyCategoryById(id).color;
