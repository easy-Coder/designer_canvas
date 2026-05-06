import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/data/canvas_image_cache.dart';

/// Builds a [ui.Paint] for solid, linear, and radial fills in [shaderRect]
/// (local coordinates used by the node painter).
ui.Paint createFillPaint({
  required FillStyleData fill,
  required ui.Rect shaderRect,
}) {
  final paint = ui.Paint()..style = ui.PaintingStyle.fill;
  switch (fill.kind) {
    case FillKind.solid:
      paint.color = fill.color;
    case FillKind.linearGradient:
      final stops = fill.effectiveStops;
      paint.shader = ui.Gradient.linear(
        _lerpRect(shaderRect, fill.linearStartX, fill.linearStartY),
        _lerpRect(shaderRect, fill.linearEndX, fill.linearEndY),
        stops.map((e) => e.color).toList(growable: false),
        stops.map((e) => e.offset.clamp(0.0, 1.0)).toList(growable: false),
      );
    case FillKind.radialGradient:
      final stops = fill.effectiveStops;
      final cx =
          shaderRect.left + fill.radialCenterX * shaderRect.width;
      final cy =
          shaderRect.top + fill.radialCenterY * shaderRect.height;
      final r = fill.radialRadius *
          0.5 *
          math.min(shaderRect.width, shaderRect.height);
      paint.shader = ui.Gradient.radial(
        ui.Offset(cx, cy),
        math.max(r, 1e-6),
        stops.map((e) => e.color).toList(growable: false),
        stops.map((e) => e.offset.clamp(0.0, 1.0)).toList(growable: false),
      );
    case FillKind.image:
      paint.color = fill.swatchColor;
  }
  return paint;
}

ui.Offset _lerpRect(ui.Rect r, double nx, double ny) {
  return ui.Offset(
    r.left + nx * r.width,
    r.top + ny * r.height,
  );
}

/// Paints an image [FillStyleData] into [targetRect] (after any clip).
void paintImageFill({
  required ui.Canvas canvas,
  required FillStyleData fill,
  required ui.Rect targetRect,
  required ui.Image? image,
}) {
  if (image == null) {
    canvas.drawRect(targetRect, createFillPaint(fill: fill, shaderRect: targetRect));
    return;
  }
  switch (fill.imageFit) {
    case FillImageFit.cover:
      _drawImageCover(canvas, image, targetRect);
    case FillImageFit.contain:
      _drawImageContain(canvas, image, targetRect);
    case FillImageFit.fill:
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        targetRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    case FillImageFit.tile:
      if (image.width <= 0 || image.height <= 0) return;
      final m = Float64List(16)
        ..[0] = 1
        ..[5] = 1
        ..[10] = 1
        ..[12] = targetRect.left
        ..[13] = targetRect.top
        ..[15] = 1;
      final shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        m,
      );
      canvas.drawRect(
        targetRect,
        ui.Paint()
          ..shader = shader
          ..filterQuality = ui.FilterQuality.medium,
      );
  }
}

void _drawImageCover(ui.Canvas canvas, ui.Image image, ui.Rect targetRect) {
  final imageW = image.width.toDouble();
  final imageH = image.height.toDouble();
  if (imageW <= 0 ||
      imageH <= 0 ||
      targetRect.width <= 0 ||
      targetRect.height <= 0) {
    return;
  }
  final targetAspect = targetRect.width / targetRect.height;
  final imageAspect = imageW / imageH;
  ui.Rect srcRect;
  if (imageAspect > targetAspect) {
    final croppedW = imageH * targetAspect;
    final left = (imageW - croppedW) / 2;
    srcRect = ui.Rect.fromLTWH(left, 0, croppedW, imageH);
  } else {
    final croppedH = imageW / targetAspect;
    final top = (imageH - croppedH) / 2;
    srcRect = ui.Rect.fromLTWH(0, top, imageW, croppedH);
  }
  canvas.drawImageRect(
    image,
    srcRect,
    targetRect,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
}

void _drawImageContain(ui.Canvas canvas, ui.Image image, ui.Rect targetRect) {
  final imageW = image.width.toDouble();
  final imageH = image.height.toDouble();
  if (imageW <= 0 ||
      imageH <= 0 ||
      targetRect.width <= 0 ||
      targetRect.height <= 0) {
    return;
  }
  final targetAspect = targetRect.width / targetRect.height;
  final imageAspect = imageW / imageH;
  double dstW;
  double dstH;
  if (imageAspect > targetAspect) {
    dstW = targetRect.width;
    dstH = targetRect.width / imageAspect;
  } else {
    dstH = targetRect.height;
    dstW = targetRect.height * imageAspect;
  }
  final dst = ui.Rect.fromCenter(
    center: targetRect.center,
    width: dstW,
    height: dstH,
  );
  final src = ui.Rect.fromLTWH(0, 0, imageW, imageH);
  canvas.drawImageRect(
    image,
    src,
    dst,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
}

/// Ensures a path is loaded and returns the image if ready.
ui.Image? imageForFillPath(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final c = CanvasImageCache.instance;
  c.ensureLoaded(path);
  return c.tryGet(path);
}
