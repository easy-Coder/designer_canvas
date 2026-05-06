import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/fill_paint.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Regular [sides]-gon inscribed in the rounded-rect frame (like [RectNode]).
class PolygonNode extends CanvasNode with RoundedRectCanvasMixin {
  PolygonNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    PolygonNodeStyle? style,
    String? label,
    super.zIndex = 2,
  }) : super(style: style ?? const PolygonNodeStyle(), label: label ?? 'Polygon') {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: rotationRadians,
    );
  }

  PolygonNodeStyle get polyStyle => style as PolygonNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! PolygonNodeStyle) return;
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

  List<ui.Offset> get _verticesWorld {
    final n = polyStyle.side.clamp(3, 64);
    final hw = rectWidth / 2;
    final hh = rectHeight / 2;
    final c = rectCenter;
    final rot = rotationRadians;
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);
    final out = <ui.Offset>[];
    for (var i = 0; i < n; i++) {
      final t = -math.pi / 2 + i * 2 * math.pi / n;
      final lx = hw * math.cos(t);
      final ly = hh * math.sin(t);
      final rx = lx * cosR - ly * sinR;
      final ry = lx * sinR + ly * cosR;
      out.add(ui.Offset(c.dx + rx, c.dy + ry));
    }
    return out;
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final s = polyStyle;
    final verts = _verticesWorld;
    final path = ui.Path();
    for (var i = 0; i < verts.length; i++) {
      final p = context.camera.globalToLocal(verts[i].dx, verts[i].dy);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
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
