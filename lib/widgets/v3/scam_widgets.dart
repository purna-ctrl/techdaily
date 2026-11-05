import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../screens/v2/scam_check_screen.dart' show ScamCheckButton;
import '../../services/v2/scam_game.dart';
import '../v2/story_parts.dart' show openExternal;
import 'story_image.dart';
import 'ui.dart';
import '../../l10n/app_language.dart' show tr;

/// Red glow that breathes (static when motion is off).
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  const PulsingGlow({super.key, required this.child, this.color = TD.red, this.radius = TD.rLg});

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Web: a static glow. Animating a large blurred shadow repaints the whole card every frame.
    if (!kIsWeb && Motion.enabled(context)) _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _box(double t) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.18 + 0.27 * t), blurRadius: 18 + 22 * t, spreadRadius: -4 + 3 * t)],
        ),
        child: RepaintBoundary(child: widget.child),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return _box(0.6);
    return AnimatedBuilder(animation: c, builder: (_, _) => _box(Curves.easeInOut.transform(c.value)));
  }
}

/// "Scam Radar": the latest scam story, its warning signs, and the helpline.
class ScamRadarCard extends StatelessWidget {
  final Story story;
  const ScamRadarCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final signs = story.scam?.warningSigns.take(2).toList() ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: PulsingGlow(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TD.rLg),
            border: Border.all(color: TD.red.withValues(alpha: 0.7), width: 1.4),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A0F14), Color(0xFF16121A)]),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => openStory(context, story),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const _RadarDot(),
                    const SizedBox(width: 10),
                    Text(tr('SCAM RADAR'), style: AppTheme.kicker(size: 12.5, color: TD.redTint).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                    const Spacer(),
                    Text(tr('Live alert'), style: AppTheme.kicker(size: 11, color: TD.muted)),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(story.headline, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTheme.display(19, color: TD.ink, height: 1.2)),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(width: 72, height: 72, child: StoryImageView(story: story, borderRadius: BorderRadius.circular(16), cacheWidth: 72)),
                  ]),
                  if (signs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final s in signs)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.warning_rounded, size: 16, color: TD.focus)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.4, color: TD.ink))),
                        ]),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    const ScamCheckButton(),
                    FilledButton.icon(
                      key: const ValueKey('radar-1930'),
                      style: FilledButton.styleFrom(backgroundColor: TD.red, foregroundColor: TD.bg, shape: const StadiumBorder(), minimumSize: const Size(0, 42)),
                      onPressed: () => openExternal(context, 'tel:1930'),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('1930'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: TD.ink, shape: const StadiumBorder(), minimumSize: const Size(0, 42), side: const BorderSide(color: TD.glassBorder)),
                      onPressed: () => openExternal(context, 'https://cybercrime.gov.in'),
                      icon: const Icon(Icons.local_police_rounded, size: 18),
                      label: const Text('cybercrime.gov.in'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarDot extends StatelessWidget {
  const _RadarDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: TD.red.withValues(alpha: 0.5), width: 2)),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: TD.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: TD.red, blurRadius: 8)]),
        ),
      ),
    );
  }
}

/// "Scam or Not?" daily game card.
class ScamOrNotCard extends StatefulWidget {
  final List<Story> stories;
  final DateTime? now;
  const ScamOrNotCard({super.key, required this.stories, this.now});

  @override
  State<ScamOrNotCard> createState() => _ScamOrNotCardState();
}

class _ScamOrNotCardState extends State<ScamOrNotCard> {
  late List<ScamMessage> _round = dailyScamRound(widget.stories, widget.now ?? DateTime.now());
  int _index = 0;
  bool? _summary; // null until the saved answers are known

  @override
  void didUpdateWidget(ScamOrNotCard old) {
    super.didUpdateWidget(old);
    if (old.stories.length != widget.stories.length) {
      _round = dailyScamRound(widget.stories, widget.now ?? DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = StoriesScope.of(context).scamGame;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (_summary == null && game.loaded) {
          // Resume where the reader left off today.
          _summary = game.isDone(_round);
          final next = _round.indexWhere((m) => game.answerFor(m) == null);
          _index = next < 0 ? _round.length - 1 : next;
        }
        final showSummary = _summary == true && game.isDone(_round);
        final m = _round[_index.clamp(0, _round.length - 1)];
        final answered = game.answerFor(m);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TD.rLg),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1530), Color(0xFF121218), Color(0xFF0F1D1A)]),
              border: Border.all(color: TD.glassBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.psychology_alt_rounded, color: Color(0xFFB090F9), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text(tr('Scam or Not?'), style: AppTheme.display(20, color: TD.ink))),
                    Text(showSummary ? tr('Done for today · new messages tomorrow') : tr('Daily game · message {i} of {n}', {'i': _index + 1, 'n': _round.length}),
                        style: const TextStyle(fontSize: 12.5, color: TD.muted)),
                  ]),
                ),
                _StreakBadge(streak: game.streak),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (c, a) => FadeTransition(
                    opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: c)),
                child: showSummary
                    ? _Summary(
                        key: const ValueKey('summary'),
                        score: game.score(_round),
                        total: _round.length,
                        streak: game.streak,
                        onReview: () => setState(() {
                          _summary = false;
                          _index = 0;
                        }),
                      )
                    : _MessageBubble(key: ValueKey(m.id), message: m),
              ),
              if (!showSummary) ...[
                const SizedBox(height: 12),
                if (answered == null)
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('answer-scam'),
                        style: FilledButton.styleFrom(backgroundColor: TD.red, foregroundColor: TD.bg, minimumSize: const Size(0, 50), shape: const StadiumBorder()),
                        onPressed: () => game.answer(m, saysScam: true, round: _round),
                        icon: const Icon(Icons.gpp_bad_rounded),
                        label: Text(tr('Scam')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('answer-safe'),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E), foregroundColor: TD.bg, minimumSize: const Size(0, 50), shape: const StadiumBorder()),
                        onPressed: () => game.answer(m, saysScam: false, round: _round),
                        icon: const Icon(Icons.verified_user_rounded),
                        label: Text(tr('Safe')),
                      ),
                    ),
                  ])
                else
                  _Explanation(
                    message: m,
                    right: answered == m.isScam,
                    isLast: _index >= _round.length - 1,
                    onNext: () => setState(() {
                      if (_index >= _round.length - 1) {
                        _summary = true;
                      } else {
                        _index++;
                      }
                    }),
                  ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$streak day streak',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9933).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFF9933).withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFB061)),
          const SizedBox(width: 4),
          Text('$streak', style: AppTheme.numeric(14, color: const Color(0xFFFFB061))),
        ]),
      ),
    );
  }
}

/// Realistic SMS / WhatsApp bubble.
class _MessageBubble extends StatelessWidget {
  final ScamMessage message;
  const _MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final wa = message.channel == 'WhatsApp';
    final bubble = wa ? const Color(0xFF1F2C33) : const Color(0xFF2A2A33);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: wa ? const Color(0xFF25D366).withValues(alpha: 0.2) : const Color(0xFF3B82F6).withValues(alpha: 0.2),
          child: Icon(wa ? Icons.chat_rounded : Icons.sms_rounded, size: 16, color: wa ? const Color(0xFF25D366) : const Color(0xFF72A5F9)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: TD.ink, fontSize: 14)),
        ),
        Text(message.channel, style: AppTheme.kicker(size: 10.5, color: TD.muted)),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
        decoration: BoxDecoration(
          color: bubble,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SelectableText(message.body, style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFFECE9E2))),
          const SizedBox(height: 4),
          const Text('now', style: TextStyle(fontSize: 11, color: Color(0xFFA9A59D))),
        ]),
      ),
    ]);
  }
}

class _Explanation extends StatelessWidget {
  final ScamMessage message;
  final bool right;
  final bool isLast;
  final VoidCallback onNext;
  const _Explanation({required this.message, required this.right, required this.isLast, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final color = right ? const Color(0xFF4ADE80) : TD.redTint;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.enabled(context) ? 0.85 : 1, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, alignment: Alignment.topCenter, child: child),
      child: Container(
        key: const ValueKey('game-explanation'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(right ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
            const SizedBox(width: 8),
            Text(right ? tr('You got it!') : tr('Not quite'), style: AppTheme.display(17, color: color)),
          ]),
          const SizedBox(height: 6),
          Text(message.verdict, style: const TextStyle(fontSize: 15, height: 1.45, color: TD.ink)),
          const SizedBox(height: 6),
          for (final s in message.signs)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(message.isScam ? Icons.warning_rounded : Icons.check_rounded, size: 15, color: message.isScam ? TD.focus : const Color(0xFF4ADE80)),
                const SizedBox(width: 6),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 13.5, height: 1.4, color: TD.ink))),
              ]),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (message.storySlug != null)
              TextButton.icon(
                onPressed: () => openStorySlug(context, message.storySlug!),
                icon: const Icon(Icons.newspaper_rounded, size: 16),
                label: Text(tr('Read the news story')),
              ),
            FilledButton(
              key: const ValueKey('game-next'),
              style: FilledButton.styleFrom(backgroundColor: TD.ink, foregroundColor: TD.bg, shape: const StadiumBorder(), minimumSize: const Size(0, 40)),
              onPressed: onNext,
              child: Text(isLast ? tr('See my score') : tr('Next message')),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final int score;
  final int total;
  final int streak;
  final VoidCallback onReview;
  const _Summary({super.key, required this.score, required this.total, required this.streak, required this.onReview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Text('$score / $total', style: AppTheme.numeric(40, color: TD.ink, family: AppTheme.displayFont)),
        const SizedBox(height: 4),
        Text(score == total ? 'Scam-proof today! 🛡️' : 'Every message teaches a trick. Back tomorrow!',
            textAlign: TextAlign.center, style: const TextStyle(color: TD.ink, fontSize: 15)),
        const SizedBox(height: 6),
        Text('🔥 $streak-day streak', style: const TextStyle(color: Color(0xFFFFB061), fontWeight: FontWeight.w700)),
        TextButton(onPressed: onReview, child: Text(tr('Review answers'))),
      ]),
    );
  }
}
