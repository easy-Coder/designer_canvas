import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

/// Equilateral triangle; [RoundedRectCanvasMixin] frame matches classic
/// width = side, height = side * sqrt(3) / 2.
class TriangleNode extends CanvasNode with RoundedRectCanvasMixin {
  TriangleNode({
    required ui.Offset center,
    required double side,
    double rotationRadians = 0,
    required this.color,
    super.zIndex = 1,
  }) {
    final h = side * math.sqrt(3) / 2;
    initRoundedRectGeometry(
      center: center,
      width: side,
      height: h,
      rotationRadians: rotationRadians,
    );
  }

  final ui.Color color;

  List<ui.Offset> get _vertices {
    final side = rectWidth;
    final r = side / math.sqrt(3.0);
    final c = rectCenter;
    final rot = rotationRadians;
    return List.generate(3, (i) {
      final a = rot + i * 2 * math.pi / 3 - math.pi / 2;
      return ui.Offset(
        c.dx + r * math.cos(a),
        c.dy + r * math.sin(a),
      );
    });
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final v = _vertices;
    final p0 = context.camera.globalToLocal(v[0].dx, v[0].dy);
    final p1 = context.camera.globalToLocal(v[1].dx, v[1].dy);
    final p2 = context.camera.globalToLocal(v[2].dx, v[2].dy);
    final path = ui.Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final fill = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(path, fill);
  }
}
