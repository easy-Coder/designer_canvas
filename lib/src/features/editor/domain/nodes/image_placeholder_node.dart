import 'dart:ui' as ui;
import 'dart:io';

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/style_painter.dart';

/// Placeholder for an image asset (checkerboard + icon).
class ImageNode extends CanvasNode with RoundedRectCanvasMixin {
  static final Map<String, ui.Image> _imageCacheByPath = <String, ui.Image>{};
  static final Set<String> _failedImagePaths = <String>{};
  static final Map<String, Future<void>> _loadingByPath =
      <String, Future<void>>{};

  ImageNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    RectNodeStyle? style,
    String? label,
    this.sourceFileName,
    this.sourceFilePath,
    this.intrinsicWidth,
    this.intrinsicHeight,
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
  String? sourceFileName;
  String? sourceFilePath;
  double? intrinsicWidth;
  double? intrinsicHeight;

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

  void setSource({
    required String fileName,
    required String filePath,
    required double intrinsicWidth,
    required double intrinsicHeight,
  }) {
    sourceFileName = fileName;
    sourceFilePath = filePath;
    this.intrinsicWidth = intrinsicWidth;
    this.intrinsicHeight = intrinsicHeight;
    if (filePath.isNotEmpty) {
      _failedImagePaths.remove(filePath);
    }
  }

  String? get _normalizedSourcePath {
    final raw = sourceFilePath;
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _ensureImageLoaded(String path) {
    if (_imageCacheByPath.containsKey(path) ||
        _failedImagePaths.contains(path) ||
        _loadingByPath.containsKey(path)) {
      return;
    }
    _loadingByPath[path] = _loadImage(path);
  }

  Future<void> _loadImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        _failedImagePaths.add(path);
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imageCacheByPath[path] = frame.image;
      _failedImagePaths.remove(path);
      ui.PlatformDispatcher.instance.scheduleFrame();
    } catch (_) {
      _failedImagePaths.add(path);
    } finally {
      _loadingByPath.remove(path);
    }
  }

  void _drawPlaceholderChecker(ui.Canvas canvas, ui.Rect rect) {
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
  }

  void _drawImageAtlas(ui.Canvas canvas, ui.Image image, ui.Rect targetRect) {
    final imageW = image.width.toDouble();
    final imageH = image.height.toDouble();
    if (imageW <= 0 ||
        imageH <= 0 ||
        targetRect.width <= 0 ||
        targetRect.height <= 0) {
      _drawPlaceholderChecker(canvas, targetRect);
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

    final scale = targetRect.width / srcRect.width;
    final rst = ui.RSTransform.fromComponents(
      rotation: 0,
      scale: scale,
      anchorX: srcRect.width / 2,
      anchorY: srcRect.height / 2,
      translateX: targetRect.center.dx,
      translateY: targetRect.center.dy,
    );
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawAtlas(
      image,
      <ui.RSTransform>[rst],
      <ui.Rect>[srcRect],
      null,
      null,
      null,
      paint,
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

    final sourcePath = _normalizedSourcePath;
    if (sourcePath != null) {
      _ensureImageLoaded(sourcePath);
    }
    final image = sourcePath == null ? null : _imageCacheByPath[sourcePath];
    if (image != null) {
      _drawImageAtlas(canvas, image, rect);
    } else {
      _drawPlaceholderChecker(canvas, rect);
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
