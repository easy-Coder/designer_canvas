import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

ui.Path _dashedPath(
  ui.Path source, {
  required double dashLength,
  required double dashGap,
}) {
  final path = ui.Path();
  for (final metric in source.computeMetrics()) {
    double distance = 0;
    while (distance < metric.length) {
      final next = math.min(distance + dashLength, metric.length);
      path.addPath(metric.extractPath(distance, next), ui.Offset.zero);
      distance += dashLength + dashGap;
    }
  }
  return path;
}

void drawStrokePath(
  ui.Canvas canvas,
  ui.Path path, {
  required StrokeStyleData stroke,
  required double zoom,
}) {
  final paint = ui.Paint()
    ..color = stroke.color
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = (stroke.width * zoom).clamp(0.5, 64)
    ..strokeCap = stroke.cap
    ..strokeJoin = stroke.join;
  switch (stroke.pattern) {
    case StrokePatternStyle.solid:
      canvas.drawPath(path, paint);
    case StrokePatternStyle.dashed:
      canvas.drawPath(
        _dashedPath(
          path,
          dashLength: stroke.dashLength * zoom,
          dashGap: stroke.dashGap * zoom,
        ),
        paint,
      );
    case StrokePatternStyle.dotted:
      canvas.drawPath(
        _dashedPath(
          path,
          dashLength: paint.strokeWidth,
          dashGap: math.max(paint.strokeWidth, stroke.dashGap * zoom),
        ),
        paint,
      );
  }
}

ui.Paint createShadowPaint(ShadowStyleData shadow) {
  return ui.Paint()
    ..color = shadow.color
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow.blurRadius);
}
