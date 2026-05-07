import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/fill_paint.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Filled circle in world space; square [RoundedRectCanvasMixin] frame, circle
/// inscribed for drawing and bbox hit testing.
class CircleNode extends CanvasNode with RoundedRectCanvasMixin {
  CircleNode({
    required ui.Offset center,
    required double radius,
    CircleNodeStyle? style,
    String? label,
    super.zIndex = 1,
  }) : super(
         style: style ?? const CircleNodeStyle(),
         label: label ?? 'Circle',
       ) {
    final d = 2 * radius;
    initRoundedRectGeometry(
      center: center,
      width: d,
      height: d,
      rotationRadians: 0,
    );
  }

  CircleNodeStyle get circleStyle => style as CircleNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! CircleNodeStyle) return;
    super.style = value;
  }

  ui.Color get color => circleStyle.fill.swatchColor;

  set color(ui.Color value) {
    style = circleStyle.copyWith(
      fill: circleStyle.fill.copyWithSolidColor(value),
    );
  }

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
    final s = circleStyle;
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final r =
        (rectWidth < rectHeight ? rectWidth : rectHeight) /
        2 *
        context.camera.zoomDouble;
    final shadow = s.shadow;
    if (shadow != null) {
      canvas.save();
      canvas.translate(
        shadow.offsetX * context.camera.zoomDouble,
        shadow.offsetY * context.camera.zoomDouble,
      );
      canvas.drawCircle(pivot, r, createShadowPaint(shadow));
      canvas.restore();
    }
    final oval = ui.Rect.fromCircle(center: pivot, radius: r);
    if (s.fill.kind == FillKind.image) {
      final img = imageForFillPath(s.fill.imagePath);
      canvas.save();
      canvas.clipPath(ui.Path()..addOval(oval));
      paintImageFill(
        canvas: canvas,
        fill: s.fill,
        targetRect: oval,
        image: img,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(
        pivot,
        r,
        createFillPaint(fill: s.fill, shaderRect: oval),
      );
    }
    final stroke = s.stroke;
    if (stroke != null) {
      final path = ui.Path()
        ..addOval(ui.Rect.fromCircle(center: pivot, radius: r));
      drawStrokePath(
        canvas,
        path,
        stroke: stroke,
        zoom: context.camera.zoomDouble,
      );
    }
  }
}
