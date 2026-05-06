import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/fill_paint.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Five-pointed star inscribed in the axis-aligned frame.
class StarNode extends CanvasNode with RoundedRectCanvasMixin {
  StarNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    RectNodeStyle? style,
    String? label,
    super.zIndex = 2,
  }) : super(style: style ?? const RectNodeStyle(), label: label ?? 'Star') {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: rotationRadians,
    );
  }

  RectNodeStyle get starStyle => style as RectNodeStyle;

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

  static const int _points = 5;

  ui.Path _starPathViewport(CanvasPaintContext context) {
    final hw = rectWidth / 2;
    final hh = rectHeight / 2;
    final c = rectCenter;
    final rot = rotationRadians;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    ui.Offset toWorld(double lx, double ly) {
      final rx = lx * cosR - ly * sinR;
      final ry = lx * sinR + ly * cosR;
      return ui.Offset(c.dx + rx, c.dy + ry);
    }

    final path = ui.Path();
    const n = _points * 2;
    for (var i = 0; i < n; i++) {
      final t = -math.pi / 2 + i * math.pi / _points;
      final outer = i.isEven;
      final rad = outer ? math.max(hw, hh) : math.min(hw, hh) * 0.42;
      final lx = rad * math.cos(t);
      final ly = rad * math.sin(t);
      final w = toWorld(lx, ly);
      final p = context.camera.globalToLocal(w.dx, w.dy);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final s = starStyle;
    final path = _starPathViewport(context);
    final shadow = s.shadow;
    if (shadow != null) {
      canvas.save();
      canvas.translate(
        shadow.offsetX * context.camera.zoomDouble,
        shadow.offsetY * context.camera.zoomDouble,
      );
      canvas.drawPath(path, createShadowPaint(shadow));
      canvas.restore();
    }
    final bounds = path.getBounds();
    if (s.fill.kind == FillKind.image) {
      final img = imageForFillPath(s.fill.imagePath);
      canvas.save();
      canvas.clipPath(path);
      paintImageFill(
        canvas: canvas,
        fill: s.fill,
        targetRect: bounds,
        image: img,
      );
      canvas.restore();
    } else {
      canvas.drawPath(
        path,
        createFillPaint(fill: s.fill, shaderRect: bounds),
      );
    }
    final stroke = s.stroke;
    if (stroke != null) {
      drawStrokePath(
        canvas,
        path,
        stroke: stroke,
        zoom: context.camera.zoomDouble,
      );
    }
  }
}
