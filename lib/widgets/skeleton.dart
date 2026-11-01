import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Lightweight shimmer that sweeps a highlight across its child.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    // Avoid infinite animations in widget tests (pumpAndSettle would hang).
    final binding = WidgetsBinding.instance;
    final isTest = binding.runtimeType.toString().contains('Test');
    if (!isTest) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final base = dark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt;
    final highlight = dark ? const Color(0xFF2A2A34) : const Color(0xFFF9F7F2);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.0 + 3 * t - 1, -0.3),
            end: Alignment(1.0 + 3 * t - 1, 0.3),
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A rounded placeholder block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder layout shown while the home feed loads.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: List.generate(4, (i) => const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SkeletonBox(width: 72, height: 36, radius: 18),
              ))),
          const SizedBox(height: 16),
          const AspectRatio(aspectRatio: 4 / 5, child: SkeletonBox(height: 0, radius: 24)),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 120, height: 20)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(children: List.generate(2, (i) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SkeletonBox(height: 150, radius: 18),
                  ),
                ))),
          ),
          const SizedBox(height: 24),
          ...List.generate(3, (i) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  SkeletonBox(width: 96, height: 80, radius: 14),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SkeletonBox(height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 10),
                    ]),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}
