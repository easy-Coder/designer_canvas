import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'node_styles.dart';
import 'style_painter.dart';

/// Line segment as a thin oriented [RoundedRectCanvasMixin] frame.
class LineNode extends CanvasNode with RoundedRectCanvasMixin {
  LineNode({
    required ui.Offset start,
    required ui.Offset end,
    LineNodeStyle? style,
    String? label,
    this.hitThicknessWorld = 8,
    super.zIndex = 1,
  }) : super(
         style: style ?? const LineNodeStyle(),
         label: label ?? 'Line',
       ) {
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

  final double hitThicknessWorld;

  LineNodeStyle get lineStyle => style as LineNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! LineNodeStyle) return;
    super.style = value;
  }

  ui.Color get color => lineStyle.stroke.color;

  set color(ui.Color value) {
    style = lineStyle.copyWith(
      stroke: lineStyle.stroke.copyWith(color: value),
    );
  }

  double get strokeWidthWorld => lineStyle.stroke.width;

  set strokeWidthWorld(double value) {
    style = lineStyle.copyWith(
      stroke: lineStyle.stroke.copyWith(width: value),
    );
  }

  /// Updates segment geometry in world space (same basis as the constructor).
  void setWorldEndpoints(ui.Offset start, ui.Offset end) {
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

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final s = lineStyle;
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final hw = rectWidth / 2 * context.camera.zoomDouble;
    final path = ui.Path()
      ..moveTo(-hw, 0)
      ..lineTo(hw, 0);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    final shadow = s.shadow;
    if (shadow != null) {
      final shadowPaint = createShadowPaint(shadow)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = (s.stroke.width * context.camera.zoomDouble).clamp(
          0.5,
          64,
        )
        ..strokeCap = s.stroke.cap;
      canvas.save();
      canvas.translate(
        shadow.offsetX * context.camera.zoomDouble,
        shadow.offsetY * context.camera.zoomDouble,
      );
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }
    drawStrokePath(
      canvas,
      path,
      stroke: s.stroke,
      zoom: context.camera.zoomDouble,
    );
    canvas.restore();
  }
}
