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
///
/// Knob size, rotate offset, and arc stroke derive from **world-space** constants
/// multiplied by [zoom] (same scale as [Camera.globalToLocalRect] extents), so
/// chrome grows and shrinks on screen like scene geometry.
final class SelectionHandles {
  SelectionHandles._();

  /// World-space half-extent of a square handle (center to edge along one axis).
  static const double handleHalfWorld = 6;

  /// World-space distance above the top edge to the rotation affordance center.
  static const double rotateOffsetWorld = 20;

  /// World-space corner radius for square knobs (RRect).
  static const double knobCornerRadiusWorld = 1;

  /// World-space stroke width for the rotation arc.
  static const double arcStrokeWidthWorld = 1.5;

  static double _knobHalfViewport(double zoom) =>
      (handleHalfWorld * zoom).clamp(2.0, 80.0);

  static double _rotateAboveTopViewport(double zoom) =>
      (rotateOffsetWorld * zoom).clamp(4.0, 120.0);

  static double _knobCornerRadiusViewport(double zoom) =>
      (knobCornerRadiusWorld * zoom).clamp(0.5, 12.0);

  static ui.Rect _knob(ui.Offset c, double half) =>
      ui.Rect.fromCenter(center: c, width: half * 2, height: half * 2);

  /// Returns the first handle hit by [local] in viewport coordinates, or null.
  ///
  /// [zoom] is [Camera.zoomDouble]; geometry scales with `zoom` like world bounds.
  static SelectionHandleKind? hitTest({
    required ui.Rect viewportRect,
    required ui.Offset local,
    required double zoom,
  }) {
    final half = _knobHalfViewport(zoom);
    final l = viewportRect.left;
    final t = viewportRect.top;
    final r = viewportRect.right;
    final b = viewportRect.bottom;
    final cx = (l + r) / 2;

    final rotAbove = _rotateAboveTopViewport(zoom);
    final rotCenter = ui.Offset(cx, t - rotAbove);
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

  /// Draws transform handles for [viewportRect] (selection union in pixels).
  static void paint({
    required ui.Canvas canvas,
    required ui.Rect viewportRect,
    required double zoom,
    required ui.Paint boxPaint,
    required ui.Paint knobFill,
    required ui.Paint knobStroke,
  }) {
    final half = _knobHalfViewport(zoom);
    final cornerR = _knobCornerRadiusViewport(zoom);
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
    final rKnob = math.min(cornerR, half * 0.99);
    for (final c in knobs) {
      final rr = ui.RRect.fromRectXY(_knob(c, half), rKnob, rKnob);
      canvas.drawRRect(rr, knobFill);
      canvas.drawRRect(rr, knobStroke);
    }

    final rot = ui.Offset(cx, t - _rotateAboveTopViewport(zoom));
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
      ..strokeWidth = (arcStrokeWidthWorld * zoom).clamp(0.5, 8.0);
    canvas.drawPath(arc, arcStroke);
  }
}
