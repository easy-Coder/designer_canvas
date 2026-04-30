import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Placeholder for an image asset (checkerboard + icon).
class ImagePlaceholderNode extends CanvasNode with RoundedRectCanvasMixin {
  ImagePlaceholderNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    RectNodeStyle? style,
    String? label,
    super.zIndex = 2,
  }) : super(style: style ?? const RectNodeStyle(), label: label ?? 'Image') {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: rotationRadians,
    );
  }

  RectNodeStyle get imageStyle => style as RectNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! RectNodeStyle) return;
    super.style = value;
  }

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
    final s = imageStyle;
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final hw = rectWidth / 2 * context.camera.zoomDouble;
    final hh = rectHeight / 2 * context.camera.zoomDouble;
    final rect = ui.Rect.fromLTWH(-hw, -hh, hw * 2, hh * 2);
    final rPx = s.cornerRadius * context.camera.zoomDouble;
    final clip = ui.RRect.fromRectXY(rect, rPx, rPx);

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    canvas.clipRRect(clip);

    const cell = 6.0;
    for (var y = rect.top; y < rect.bottom; y += cell) {
      for (var x = rect.left; x < rect.right; x += cell) {
        final light =
            ((x - rect.left) ~/ cell + (y - rect.top) ~/ cell) % 2 == 0;
        final paint = ui.Paint()
          ..color = light
              ? const ui.Color(0xFFE0E0E0)
              : const ui.Color(0xFFBDBDBD)
          ..style = ui.PaintingStyle.fill;
        canvas.drawRect(
          ui.Rect.fromLTWH(x, y, cell, cell).intersect(rect),
          paint,
        );
      }
    }
    canvas.restore();

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotationRadians);
    final stroke = s.stroke;
    if (stroke != null) {
      final path = ui.Path()..addRRect(clip);
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
