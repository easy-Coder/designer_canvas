import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';

/// Line segment with an arrowhead at the end (world-space).
class ArrowNode extends LineNode {
  // ignore: use_super_parameters
  ArrowNode({
    required ui.Offset start,
    required ui.Offset end,
    LineNodeStyle? style,
    String? label,
    int zIndex = 2,
  }) : super(start: start, end: end, style: style, label: label ?? 'Arrow', zIndex: zIndex);

  static const double _arrowHeadLengthWorld = 14;
  static const double _arrowHeadWidthWorld = 10;

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final halfLength = rectWidth / 2;
    final dx = math.cos(rotationRadians) * halfLength;
    final dy = math.sin(rotationRadians) * halfLength;
    final endWorld = ui.Offset(rectCenter.dx + dx, rectCenter.dy + dy);
    final pivot = context.camera.globalToLocal(rectCenter.dx, rectCenter.dy);
    final endLocal = context.camera.globalToLocal(endWorld.dx, endWorld.dy);
    final dir = endLocal - pivot;
    final len = dir.distance;
    if (len < 1e-3) return;
    final u = dir / len;
    final perp = ui.Offset(-u.dy, u.dx);
    final zoom = context.camera.zoomDouble;
    final back = u * (-_arrowHeadLengthWorld * zoom);
    final w = perp * (_arrowHeadWidthWorld * zoom / 2);
    final tip = endLocal;
    final left = tip + back + w;
    final right = tip + back - w;
    final head = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final s = lineStyle;
    final fill = ui.Paint()
      ..color = s.stroke.color
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(head, fill);
    if (s.stroke.width > 0) {
      canvas.drawPath(
        head,
        ui.Paint()
          ..color = s.stroke.color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = (s.stroke.width * zoom).clamp(0.5, 8),
      );
    }
  }
}
