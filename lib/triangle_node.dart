import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

/// Equilateral triangle inscribed in the mixin frame: `width = side`,
/// `height = side * sqrt(3) / 2`. [center] / [rectCenter] is the triangle’s
/// axis-aligned bounding-box center (apex toward smaller world y when
/// [rotationRadians] is 0).
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

  ui.Color color;

  /// Updates equilateral triangle from center and side length (live placement).
  void setCenterAndSide(ui.Offset center, double side) {
    final h = side * math.sqrt(3) / 2;
    initRoundedRectGeometry(
      center: center,
      width: side,
      height: h,
      rotationRadians: 0,
    );
  }

  List<ui.Offset> get _vertices {
    final w = rectWidth;
    final h = rectHeight;
    final c = rectCenter;
    final rot = rotationRadians;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    ui.Offset toWorld(ui.Offset local) {
      final rx = local.dx * cosR - local.dy * sinR;
      final ry = local.dx * sinR + local.dy * cosR;
      return ui.Offset(c.dx + rx, c.dy + ry);
    }

    return [
      toWorld(ui.Offset(0, -h / 2)),
      toWorld(ui.Offset(-w / 2, h / 2)),
      toWorld(ui.Offset(w / 2, h / 2)),
    ];
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
