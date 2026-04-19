import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

/// Line segment as a thin oriented [RoundedRectCanvasMixin] frame.
class LineNode extends CanvasNode with RoundedRectCanvasMixin {
  LineNode({
    required ui.Offset start,
    required ui.Offset end,
    required this.color,
    this.strokeWidthWorld = 3,
    this.hitThicknessWorld = 8,
    super.zIndex = 1,
  }) {
    final d = end - start;
    final len = d.distance;
    final theta = math.atan2(d.dy, d.dx);
    final center = ui.Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );
    initRoundedRectGeometry(
      center: center,
      width: math.max(len, 1e-6),
      height: hitThicknessWorld,
      rotationRadians: theta,
    );
  }

  final ui.Color color;
  final double strokeWidthWorld;
  final double hitThicknessWorld;

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final hw = rectWidth / 2 * context.camera.zoomDouble;
    final stroke = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = (strokeWidthWorld * context.camera.zoomDouble).clamp(
        0.5,
        24.0,
      )
      ..strokeCap = ui.StrokeCap.round;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    canvas.drawLine(ui.Offset(-hw, 0), ui.Offset(hw, 0), stroke);
    canvas.restore();
  }
}
