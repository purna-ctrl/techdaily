import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'category_art_data.dart';

/// Generated category artwork (gradient mesh + motif), the same design as the
/// static site's `/art/<category>.svg`. Shown whenever a story has no image or
/// its image fails to load — never a blank box.
class CategoryArtwork extends StatelessWidget {
  final String categoryId;
  final BorderRadius? borderRadius;

  /// Where the 1200x675 artwork is anchored when it is cropped (cover fit).
  final Alignment alignment;
  const CategoryArtwork({super.key, required this.categoryId, this.borderRadius, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final spec = kCategoryArt[categoryId] ?? kCategoryArt['innovations']!;
    Widget child = RepaintBoundary(
      child: CustomPaint(painter: CategoryArtPainter(spec, alignment), child: const SizedBox.expand()),
    );
    if (borderRadius != null) child = ClipRRect(borderRadius: borderRadius!, child: child);
    return ExcludeSemantics(child: child);
  }
}

class CategoryArtPainter extends CustomPainter {
  final ArtSpec spec;
  final Alignment alignment;
  CategoryArtPainter(this.spec, [this.alignment = Alignment.center]);

  static const double _w = 1200, _h = 675;

  Color _c(String key) => switch (key) {
        'c' => spec.base,
        'w' => Colors.white,
        _ => spec.tint,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF0B0B0F), spec.bgEnd],
        ).createShader(rect),
    );
    // Cover-fit the 1200x675 design.
    final scale = math.max(size.width / _w, size.height / _h);
    final dx = (size.width - _w * scale) * (alignment.x + 1) / 2;
    final dy = (size.height - _h * scale) * (alignment.y + 1) / 2;
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(dx, dy);
    canvas.scale(scale);
    final palette = [spec.base, spec.secondary, spec.tertiary];
    for (final b in spec.blobs) {
      final c = palette[b[3].toInt()];
      final center = Offset(b[0], b[1]);
      final r = b[2];
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [c.withValues(alpha: b[4]), c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    // Dot grid
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (double x = 2; x < _w; x += 24) {
      for (double y = 2; y < _h; y += 24) {
        canvas.drawCircle(Offset(x, y), 1.4, dot);
      }
    }
    for (final p in spec.prims) {
      _prim(canvas, p);
    }
    canvas.restore();
  }

  void _prim(Canvas canvas, ArtPrim p) {
    final paint = Paint()
      ..color = _c(p.colour).withValues(alpha: p.opacity)
      ..isAntiAlias = true;
    if (p.strokeWidth > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    final v = p.v;
    switch (p.kind) {
      case 'circle':
        canvas.drawCircle(Offset(v[0], v[1]), v[2], paint);
      case 'line':
        canvas.drawLine(Offset(v[0], v[1]), Offset(v[2], v[3]), paint..style = PaintingStyle.stroke);
      case 'poly':
        final path = Path()..moveTo(v[0], v[1]);
        for (var i = 2; i + 1 < v.length; i += 2) {
          path.lineTo(v[i], v[i + 1]);
        }
        if (p.closed) path.close();
        canvas.drawPath(path, paint);
      case 'rrect':
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(v[0], v[1], v[2], v[3]), Radius.circular(v[4]));
        if (v[5] != 0) {
          final c = r.center;
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(v[5] * math.pi / 180);
          canvas.translate(-c.dx, -c.dy);
          canvas.drawRRect(r, paint);
          canvas.restore();
        } else {
          canvas.drawRRect(r, paint);
        }
      case 'ellipse':
        canvas.save();
        canvas.translate(v[0], v[1]);
        canvas.rotate(v[4] * math.pi / 180);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: v[2] * 2, height: v[3] * 2), paint);
        canvas.restore();
      case 'arc':
        canvas.drawArc(Rect.fromCircle(center: Offset(v[0], v[1]), radius: v[2]), v[3] * math.pi / 180,
            v[4] * math.pi / 180, false, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(CategoryArtPainter old) => old.spec != spec || old.alignment != alignment;
}
