import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

/// Filled rounded rectangle in world space; geometry and transforms use
/// [RoundedRectCanvasMixin], appearance is app-defined in [draw].
class RectNode extends CanvasNode with RoundedRectCanvasMixin {
  RectNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    required this.color,
    this.cornerRadiusWorld = 8,
    super.zIndex = 1,
  }) {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: rotationRadians,
    );
  }

  factory RectNode.fromAxisAlignedRect(
    ui.Rect rect, {
    ui.Color color = const ui.Color(0x00000000),
    double cornerRadiusWorld = 8,
    int zIndex = 0,
  }) {
    return RectNode(
      center: rect.center,
      width: rect.width,
      height: rect.height,
      color: color,
      cornerRadiusWorld: cornerRadiusWorld,
      zIndex: zIndex,
    );
  }

  ui.Color color;
  double cornerRadiusWorld;

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
    final pivot = context.camera.globalToLocal(
      rectCenter.dx,
      rectCenter.dy,
    );
    final hw = rectWidth / 2 * context.camera.zoomDouble;
    final hh = rectHeight / 2 * context.camera.zoomDouble;
    final rPx = cornerRadiusWorld * context.camera.zoomDouble;
    final local = ui.RRect.fromRectXY(
      ui.Rect.fromLTWH(-hw, -hh, hw * 2, hh * 2),
      rPx,
      rPx,
    );

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    final fill = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(local, fill);
    canvas.restore();
  }
}
