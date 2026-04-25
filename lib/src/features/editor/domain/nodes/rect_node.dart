import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Filled rounded rectangle in world space; geometry and transforms use
/// [RoundedRectCanvasMixin], appearance is app-defined in [draw].
class RectNode extends CanvasNode with RoundedRectCanvasMixin {
  RectNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    RectNodeStyle? style,
    String? label,
    super.zIndex = 1,
  }) : super(
         style: style ?? const RectNodeStyle(),
         label: label ?? 'Rectangle',
       ) {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: rotationRadians,
    );
  }

  factory RectNode.fromAxisAlignedRect(
    ui.Rect rect, {
    RectNodeStyle style = const RectNodeStyle(
      fill: FillStyleData(color: ui.Color(0x00000000)),
    ),
    String? label,
    int zIndex = 0,
  }) {
    return RectNode(
      center: rect.center,
      width: rect.width,
      height: rect.height,
      style: style,
      label: label,
      zIndex: zIndex,
    );
  }

  RectNodeStyle get rectStyle => style as RectNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! RectNodeStyle) return;
    super.style = value;
  }

  ui.Color get color => rectStyle.fill.color;

  set color(ui.Color value) {
    style = rectStyle.copyWith(fill: rectStyle.fill.copyWith(color: value));
  }

  double get cornerRadiusWorld => rectStyle.cornerRadius;

  set cornerRadiusWorld(double value) {
    style = rectStyle.copyWith(cornerRadius: value);
  }

  /// Updates axis-aligned world geometry (used for live placement drag).
  void setAxisAlignedWorldRect(ui.Rect r) {
    initRoundedRectGeometry(
      center: r.center,
      width: r.width,
      height: r.height,
      rotationRadians: 0,
    );
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final s = rectStyle;
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final hw = rectWidth / 2 * context.camera.zoomDouble;
    final hh = rectHeight / 2 * context.camera.zoomDouble;
    final rPx = s.cornerRadius * context.camera.zoomDouble;
    final local = ui.RRect.fromRectXY(
      ui.Rect.fromLTWH(-hw, -hh, hw * 2, hh * 2),
      rPx,
      rPx,
    );

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    final shadow = s.shadow;
    if (shadow != null) {
      canvas.save();
      canvas.translate(
        shadow.offsetX * context.camera.zoomDouble,
        shadow.offsetY * context.camera.zoomDouble,
      );
      canvas.drawRRect(local, createShadowPaint(shadow));
      canvas.restore();
    }
    final fill = ui.Paint()
      ..color = s.fill.color
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(local, fill);
    final stroke = s.stroke;
    if (stroke != null) {
      final path = ui.Path()..addRRect(local);
      drawStrokePath(
        canvas,
        path,
        stroke: stroke,
        zoom: context.camera.zoomDouble,
      );
    }
    canvas.restore();
  }
}
