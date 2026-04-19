import 'dart:math' as math;
import 'dart:ui' as ui;

/// Which transform affordance was hit (scale / rotate UI is visual only for now).
enum SelectionHandleKind {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  rotate,
}

/// Hit-test and paint selection transform handles in **viewport** space.
final class SelectionHandles {
  SelectionHandles._();

  /// Screen-space half-extent of a square handle (before zoom compensation).
  static const double handleHalfPx = 6;

  /// Pixels above the top edge for the rotation affordance.
  static const double rotateOffsetPx = 28;

  static double _handleSize(double zoom) => handleHalfPx * 2 / zoom.clamp(0.01, 1.0);

  static ui.Rect _knob(ui.Offset c, double half) =>
      ui.Rect.fromCenter(center: c, width: half * 2, height: half * 2);

  /// Returns the first handle hit by [local] in viewport coordinates, or null.
  static SelectionHandleKind? hitTest({
    required ui.Rect viewportRect,
    required ui.Offset local,
    required double zoom,
  }) {
    final half = _handleSize(zoom) / 2;
    final l = viewportRect.left;
    final t = viewportRect.top;
    final r = viewportRect.right;
    final b = viewportRect.bottom;
    final cx = (l + r) / 2;

    final rotCenter = ui.Offset(cx, t - rotateOffsetPx / zoom);
    if (ui.Offset(local.dx - rotCenter.dx, local.dy - rotCenter.dy).distance <=
        half * 1.2) {
      return SelectionHandleKind.rotate;
    }

    final corners = <(SelectionHandleKind, ui.Offset)>[
      (SelectionHandleKind.topLeft, ui.Offset(l, t)),
      (SelectionHandleKind.topRight, ui.Offset(r, t)),
      (SelectionHandleKind.bottomRight, ui.Offset(r, b)),
      (SelectionHandleKind.bottomLeft, ui.Offset(l, b)),
    ];
    for (final (k, c) in corners) {
      if (_knob(c, half).contains(local)) return k;
    }

    final edgeTol = half * 1.5;
    if ((local.dy - t).abs() < edgeTol && local.dx > l && local.dx < r) {
      return SelectionHandleKind.top;
    }
    if ((local.dy - b).abs() < edgeTol && local.dx > l && local.dx < r) {
      return SelectionHandleKind.bottom;
    }
    if ((local.dx - l).abs() < edgeTol && local.dy > t && local.dy < b) {
      return SelectionHandleKind.left;
    }
    if ((local.dx - r).abs() < edgeTol && local.dy > t && local.dy < b) {
      return SelectionHandleKind.right;
    }
    return null;
  }

  /// Draw selection chrome for the primary node in viewport space.
  static void paint({
    required ui.Canvas canvas,
    required ui.Rect viewportRect,
    required double zoom,
    required ui.Paint boxPaint,
    required ui.Paint knobFill,
    required ui.Paint knobStroke,
  }) {
    final half = _handleSize(zoom) / 2;
    canvas.drawRect(viewportRect, boxPaint);

    final l = viewportRect.left;
    final t = viewportRect.top;
    final r = viewportRect.right;
    final b = viewportRect.bottom;
    final cx = (l + r) / 2;

    final knobs = <ui.Offset>[
      ui.Offset(l, t),
      ui.Offset(cx, t),
      ui.Offset(r, t),
      ui.Offset(r, (t + b) / 2),
      ui.Offset(r, b),
      ui.Offset(cx, b),
      ui.Offset(l, b),
      ui.Offset(l, (t + b) / 2),
    ];
    for (final c in knobs) {
      canvas.drawRRect(
        ui.RRect.fromRectXY(_knob(c, half), 2, 2),
        knobFill,
      );
      canvas.drawRRect(
        ui.RRect.fromRectXY(_knob(c, half), 2, 2),
        knobStroke,
      );
    }

    final rot = ui.Offset(cx, t - rotateOffsetPx / zoom);
    canvas.drawCircle(rot, half * 1.1, knobFill);
    canvas.drawCircle(rot, half * 1.1, knobStroke);

    final a0 = -math.pi * 0.75;
    final a1 = -math.pi * 0.25;
    final arc = ui.Path()
      ..addArc(
        ui.Rect.fromCircle(center: rot, radius: half * 1.6),
        a0,
        a1 - a0,
      );
    final arcStroke = ui.Paint()
      ..color = knobStroke.color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.5 / zoom);
    canvas.drawPath(arc, arcStroke);
  }
}
