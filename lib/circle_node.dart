import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

/// Filled circle in world space; square [RoundedRectCanvasMixin] frame, circle
/// inscribed for drawing and bbox hit testing.
class CircleNode extends CanvasNode with RoundedRectCanvasMixin {
  CircleNode({
    required ui.Offset center,
    required double radius,
    required this.color,
    super.zIndex = 1,
  }) {
    final d = 2 * radius;
    initRoundedRectGeometry(
      center: center,
      width: d,
      height: d,
      rotationRadians: 0,
    );
  }

  final ui.Color color;

  /// Updates center and radius from world space (used for live placement drag).
  void setCenterAndRadius(ui.Offset center, double radius) {
    final d = math.max(2 * radius, 1e-6);
    initRoundedRectGeometry(
      center: center,
      width: d,
      height: d,
      rotationRadians: 0,
    );
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final r =
        (rectWidth < rectHeight ? rectWidth : rectHeight) / 2 * context.camera.zoomDouble;
    final fill = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(pivot, r, fill);
  }
}
