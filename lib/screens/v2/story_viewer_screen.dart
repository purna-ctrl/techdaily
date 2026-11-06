import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/stories_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../models/story.dart';
import '../../widgets/v3/story_cards.dart' show metaLine, oneLiner;
import '../../widgets/v3/story_image.dart';
import '../../widgets/v3/story_rings.dart' show markStoryViewed;
import '../../widgets/v3/ui.dart';
import 'reels_screen.dart';
import '../../l10n/app_language.dart' show tr;

/// Full-screen "Today in 5" viewer: progress bars, auto-advance, tap
/// left/right, hold to pause, swipe up for the full story. After the last
/// story: "You're all caught up" with the streak.
class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  final Duration perStory;
  const StoryViewerScreen({super.key, required this.stories, this.initialIndex = 0, this.perStory = const Duration(seconds: 7)});

  static Future<void> open(BuildContext context, List<Story> stories, int index) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => StoryViewerScreen(stories: stories, initialIndex: index),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    ));
  }

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.perStory)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  late int _index = widget.initialIndex;
  bool _auto = true;
  int? _streak;
  bool _started = false;

  int get _count => widget.stories.length;
  bool get _onFinale => _index >= _count;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _auto = Motion.enabled(context);
    _start();
  }

  void _start() {
    if (_onFinale) return;
    final id = widget.stories[_index].id;
    WidgetsBinding.instance.addPostFrameCallback((_) => markStoryViewed(id));
    _progress.value = 0;
    if (_auto) _progress.forward();
  }

  void _go(int i) {
    if (i < 0) {
      _progress.value = 0;
      if (_auto) _progress.forward();
      return;
    }
    if (i > _count) {
      Navigator.of(context).maybePop();
      return;
    }
    _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _next() => _go(_index + 1);
  void _prev() => _go(_index - 1);

  Future<void> _onPage(int i) async {
    setState(() => _index = i);
    if (i >= _count) {
      _progress.stop();
      final s = await StoriesScope.of(context).caughtUp.markDone();
      if (mounted) setState(() => _streak = s);
    } else {
      _start();
    }
  }

  Future<void> _openDetail() async {
    if (_onFinale) return;
    _progress.stop();
    await openStory(context, widget.stories[_index]);
    if (mounted && _auto && !_onFinale) _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
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
          controller: _pages,
          itemCount: _count + 1,
          onPageChanged: _onPage,
          itemBuilder: (context, i) => i == _count
              ? _CaughtUp(streak: _streak, onClose: () => Navigator.of(context).maybePop(), stories: widget.stories)
              : _StoryPage(
                  story: widget.stories[i],
                  onTapLeft: _prev,
                  onTapRight: _next,
                  onHold: (down) => down ? _progress.stop() : (_auto ? _progress.forward() : null),
                  onSwipeUp: _openDetail,
                ),
        ),
        if (!_onFinale)
          Positioned(
            top: pad.top + 8,
            left: 10,
            right: 10,
            child: Column(children: [
              Row(children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 3.5,
                          child: i == _index
                              ? AnimatedBuilder(
                                  animation: _progress,
                                  builder: (_, _) => LinearProgressIndicator(
                                    value: _auto ? _progress.value : 0.5,
                                    backgroundColor: Colors.white24,
                                    color: Colors.white,
                                  ),
                                )
                              : ColoredBox(color: i < _index ? Colors.white : Colors.white24),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(tr('Today in {n}', {'n': _count}), style: AppTheme.display(15, color: Colors.white)),
                const SizedBox(width: 8),
                Text('${_index + 1}/$_count', style: AppTheme.numeric(13, color: Colors.white70)),
                const Spacer(),
                IconButton(
                  tooltip: tr('Close'),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x660B0B0F)),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _StoryPage extends StatelessWidget {
  final Story story;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;
  final void Function(bool down) onHold;
  final VoidCallback onSwipeUp;
  const _StoryPage({required this.story, required this.onTapLeft, required this.onTapRight, required this.onHold, required this.onSwipeUp});

  @override
  Widget build(BuildContext context) {
    final cat = story.categoryInfo;
    final line = oneLiner(story) ?? story.whatHappened;
    final pad = MediaQuery.paddingOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final w = MediaQuery.sizeOf(context).width;
        d.localPosition.dx < w / 3 ? onTapLeft() : onTapRight();
      },
      onLongPressStart: (_) => onHold(true),
      onLongPressEnd: (_) => onHold(false),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -250) onSwipeUp();
      },
      child: Stack(fit: StackFit.expand, children: [
        ScrimmedImage(
          story: story,
          showCredit: false,
          scrim: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [0, 0.5, 0.78, 1],
            colors: [Color(0xFC0B0B0F), Color(0xE00B0B0F), Color(0x330B0B0F), Color(0x990B0B0F)],
          ),
        ),
        // Category glow at the bottom edge
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 6,
          child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [cat.color, cat.tint, cat.color]))),
        ),
        if (story.image != null) Positioned(top: pad.top + 74, right: 12, child: ImageCredit(story: story)),
        Positioned(
          left: 20,
          right: 20,
          bottom: pad.bottom + 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              CategoryChip(category: cat, glow: true),
              if (story.developing) const DevelopingPill(),
            ]),
            const SizedBox(height: 12),
            Text(story.headline, maxLines: 5, overflow: TextOverflow.ellipsis, style: AppTheme.display(30, color: Colors.white, height: 1.1)),
            const SizedBox(height: 10),
            Text(line, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.45, color: Color(0xFFE2DED6))),
            const SizedBox(height: 8),
            Text(metaLine(story), style: const TextStyle(fontSize: 13, color: Color(0xFFD2CEC6))),
            const SizedBox(height: 18),
            Center(
              child: Semantics(
                button: true,
                label: tr('Open the full story'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onSwipeUp,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const _Bounce(child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28)),
                      Text(tr('Swipe up for the full story'), style: AppTheme.kicker(size: 11.5, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Bounce extends StatefulWidget {
  final Widget child;
  const _Bounce({required this.child});

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.enabled(context)) _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return AnimatedBuilder(animation: c, builder: (_, child) => Transform.translate(offset: Offset(0, -5 * Curves.easeInOut.transform(c.value)), child: child), child: widget.child);
  }
}

/// "You're all caught up" with confetti and the streak.
class _CaughtUp extends StatefulWidget {
  final int? streak;
  final VoidCallback onClose;
  final List<Story> stories;
  const _CaughtUp({required this.streak, required this.onClose, required this.stories});

  @override
  State<_CaughtUp> createState() => _CaughtUpState();
}

class _CaughtUpState extends State<_CaughtUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.enabled(context) && !_c.isAnimating && _c.value == 0) _c.forward();
    if (!Motion.enabled(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF3A1A0E), Color(0xFF16101F), TD.bg]),
      ),
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _Confetti(_c.value)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFFF5A1F), Color(0xFFFF3B4E), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: Color(0x88FF5A1F), blurRadius: 40)],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
              ),
              const SizedBox(height: 24),
              Semantics(header: true, child: Text(tr('You’re all caught up'), textAlign: TextAlign.center, style: AppTheme.display(32, color: TD.ink))),
              const SizedBox(height: 10),
              Text('That’s today’s ${widget.stories.length} stories that matter, in simple words.',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5, color: TD.muted)),
              const SizedBox(height: 22),
              if (streak != null)
                Container(
                  key: const ValueKey('caught-up-streak'),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFFF9933).withValues(alpha: 0.14),
                    border: Border.all(color: const Color(0xFFFF9933).withValues(alpha: 0.6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB061)),
                    const SizedBox(width: 8),
                    Text('$streak-day streak', style: AppTheme.display(18, color: const Color(0xFFFFB061))),
                  ]),
                ),
              const SizedBox(height: 30),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: TD.ink, foregroundColor: TD.bg, minimumSize: const Size(240, 52), shape: const StadiumBorder()),
                onPressed: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ReelsScreen(stories: widget.stories)));
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: Text(tr('Keep reading in Reels')),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: widget.onClose, child: Text(tr('Back to home'))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Confetti extends CustomPainter {
  final double t;
  _Confetti(this.t);

  static const _colors = [Color(0xFFFF5A1F), Color(0xFF8B5CF6), Color(0xFF22C55E), Color(0xFFEAB308), Color(0xFF06B6D4), Color(0xFFFF3B4E), Color(0xFFFF9933)];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(42);
    for (var i = 0; i < 90; i++) {
      final x0 = size.width * (0.2 + rnd.nextDouble() * 0.6);
      final vx = (rnd.nextDouble() - 0.5) * size.width * 1.1;
      final vy = -size.height * (0.5 + rnd.nextDouble() * 0.6);
      final x = x0 + vx * t;
      final y = size.height * 0.42 + vy * t + size.height * 1.4 * t * t;
      final rot = t * (6 + rnd.nextDouble() * 10);
      final p = Paint()..color = _colors[i % _colors.length].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 9, height: 5), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
