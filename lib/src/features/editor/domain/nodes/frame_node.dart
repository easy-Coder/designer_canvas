import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/fill_paint.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

class FrameNode extends CanvasNode with RoundedRectCanvasMixin {
  FrameNode({
    required ui.Offset center,
    required double width,
    required double height,
    FrameNodeStyle? style,
    String? label,
    super.zIndex = 0,
  }) : super(style: style ?? const FrameNodeStyle(), label: label ?? 'Frame') {
    initRoundedRectGeometry(
      center: center,
      width: width,
      height: height,
      rotationRadians: 0,
    );
  }

  factory FrameNode.fromAxisAlignedRect(
    ui.Rect rect, {
    FrameNodeStyle style = const FrameNodeStyle(),
    String? label,
    int zIndex = 0,
  }) {
    return FrameNode(
      center: rect.center,
      width: rect.width,
      height: rect.height,
      style: style,
      label: label,
      zIndex: zIndex,
    );
  }

  FrameNodeStyle get frameStyle => style as FrameNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! FrameNodeStyle) return;
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
    final s = frameStyle;
    final localRect = context.worldRectToViewport(bounds);
    final shadow = s.shadow;
    if (shadow != null) {
      canvas.save();
      canvas.translate(
        shadow.offsetX * context.camera.zoomDouble,
        shadow.offsetY * context.camera.zoomDouble,
      );
      canvas.drawRect(localRect, createShadowPaint(shadow));
      canvas.restore();
    }
    if (s.fill.kind == FillKind.image) {
      final img = imageForFillPath(s.fill.imagePath);
      paintImageFill(
        canvas: canvas,
        fill: s.fill,
        targetRect: localRect,
        image: img,
      );
    } else {
      canvas.drawRect(
        localRect,
        createFillPaint(fill: s.fill, shaderRect: localRect),
      );
    }
    final stroke = s.stroke;
    if (stroke != null) {
      final path = ui.Path()..addRect(localRect);
      drawStrokePath(
        canvas,
        path,
        stroke: stroke,
        zoom: context.camera.zoomDouble,
      );
    }
  }
}
