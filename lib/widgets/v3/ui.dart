import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/constants/story_categories.dart';
import '../../core/theme/app_theme.dart';

/// v3 design tokens (dark-first; WCAG AA on every text colour used here).
class TD {
  TD._();
  static const Color bg = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF15151B);
  static const Color surface2 = Color(0xFF1E1E26);
  static const Color ink = Color(0xFFF4F2EC);
  static const Color muted = Color(0xFFB9B5AD); // 8.9:1 on surface
  static const Color glass = Color(0x0FFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color focus = Color(0xFFFFD166);
  static const Color red = Color(0xFFFF3B4E);
  static const Color redTint = Color(0xFFFF7683);
  static const Color whatsapp = Color(0xFF25D366);
  static const double rSm = 14, rMd = 20, rLg = 24, rXl = 28;

  /// Scrim under text that sits on photos: >= 88% ink at the text.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0, 0.45, 0.75, 1],
    colors: [Color(0xFA0B0B0F), Color(0xE60B0B0F), Color(0x660B0B0F), Color(0x330B0B0F)],
  );
}

/// Motion is off when the user asks for reduced motion (and in widget tests,
/// where endless animations would never settle).
class Motion {
  Motion._();
  static bool? debugOverride;
  static bool enabled(BuildContext context) {
    if (debugOverride != null) return debugOverride!;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return !binding.contains('Test');
  }
}

/// Frosted glass surface with a hairline border and optional colour glow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? glow;
  final Color? borderColor;
  final Color? tint;
  final double radius;
  final bool blur;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.glow,
    this.borderColor,
    this.tint,
    this.radius = TD.rLg,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tint != null
              ? [tint!.withValues(alpha: 0.13), tint!.withValues(alpha: 0.05)]
              : const [Color(0x10FFFFFF), Color(0x07FFFFFF)],
        ),
        border: Border.all(color: borderColor ?? TD.glassBorder),
      ),
      child: child,
    );
    if (blur) {
      body = ClipRRect(borderRadius: br, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: body));
    }
    return Container(
      margin: margin,
      decoration: glow == null
          ? null
          : BoxDecoration(borderRadius: br, boxShadow: [BoxShadow(color: glow!.withValues(alpha: 0.28), blurRadius: 36, spreadRadius: -8, offset: const Offset(0, 14))]),
      child: body,
    );
  }
}

/// Solid category chip: ink text on the category colour (>= 4.6:1).
class CategoryChip extends StatelessWidget {
  final StoryCategory category;
  final bool small;
  final bool glow;
  const CategoryChip({super.key, required this.category, this.small = false, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: glow ? [BoxShadow(color: category.color.withValues(alpha: 0.45), blurRadius: 18)] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(category.icon, size: small ? 12 : 14, color: TD.bg),
        SizedBox(width: small ? 4 : 5),
        Text(
          (small ? category.shortLabel : category.label).toUpperCase(),
          style: AppTheme.kicker(size: small ? 10 : 11, color: TD.bg).copyWith(fontWeight: FontWeight.w800),
        ),
      ]),
    );
  }
}

class DevelopingPill extends StatelessWidget {
  final bool small;
  const DevelopingPill({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Few or unconfirmed reports so far — details may change',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 3 : 5),
        decoration: BoxDecoration(
          color: const Color(0xEB2B2205),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF6B560E)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: TD.focus, shape: BoxShape.circle, boxShadow: [BoxShadow(color: TD.focus, blurRadius: 6)]),
          ),
          const SizedBox(width: 5),
          Text('DEVELOPING', style: AppTheme.kicker(size: small ? 9.5 : 10.5, color: TD.focus).copyWith(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Fades + slides its child in once (skipped when motion is off).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double offset;
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 18});

  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index.clamp(0, 6)) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: c)),
      child: child,
    );
  }
}

/// Slight press-down scale for tappable cards, with a visible focus ring.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final String? semanticLabel;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.radius = TD.rLg, this.semanticLabel});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              foregroundDecoration: _focused
                  ? BoxDecoration(borderRadius: br, border: Border.all(color: TD.focus, width: 3))
                  : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmering skeleton block for loading states.
class Shimmer extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Shimmer({super.key, this.width, required this.height, this.radius = TD.rMd});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.enabled(context)) {
      _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    Widget box(double t) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, -0.3),
              end: Alignment(-0.5 + 3 * t, 0.3),
              colors: const [TD.surface, TD.surface2, TD.surface],
            ),
          ),
        );
    if (c == null) return box(0.5);
    return AnimatedBuilder(animation: c, builder: (_, _) => box(c.value));
  }
}

/// Section title row: "Scam Radar ······ See all".
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.icon, this.color, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 8, 12),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: (color ?? TD.ink).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: color ?? TD.ink),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Semantics(header: true, child: Text(title, style: AppTheme.display(22, color: TD.ink, height: 1.1))),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: color ?? AppTheme.accentDark),
            child: Text(action!),
          ),
      ]),
    );
  }
}
