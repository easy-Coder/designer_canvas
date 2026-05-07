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
/// LOD behavior:
///
/// - When `zoom < _minVisibleZoom` the knobs and rotate affordance are
///   hidden entirely and [hitTest] returns `null`. The selection bounding
///   rect (drawn separately by the painter) still shows.
/// - At every other zoom level handles render at a fixed pixel size so the
///   chrome stays consistently small at high zoom and never balloons at
///   low zoom.
final class SelectionHandles {
  SelectionHandles._();

  /// Below this zoom level the handles disappear and become non-interactive.
  static const double _minVisibleZoom = 0.3;

  /// Viewport-pixel half-extent of a square handle (full knob is 14 x 14).
  static const double _handleHalfPx = 7.0;

  /// Viewport-pixel distance above the top edge to the rotate affordance.
  static const double _rotateOffsetPx = 22.0;

  /// Viewport-pixel corner radius for square knobs (RRect).
  static const double _knobCornerRadiusPx = 2.0;

  /// Viewport-pixel stroke width for the rotation arc.
  static const double _arcStrokeWidthPx = 1.5;

  static bool _handlesVisibleAt(double zoom) => zoom >= _minVisibleZoom;

  static ui.Rect _knob(ui.Offset c, double half) =>
      ui.Rect.fromCenter(center: c, width: half * 2, height: half * 2);

  /// Returns the first handle hit by [local] in viewport coordinates, or
  /// null. Always returns null when handles are hidden by LOD.
  static SelectionHandleKind? hitTest({
    required ui.Rect viewportRect,
    required ui.Offset local,
    required double zoom,
  }) {
    if (!_handlesVisibleAt(zoom)) return null;

    const half = _handleHalfPx;
    final l = viewportRect.left;
    final t = viewportRect.top;
    final r = viewportRect.right;
    final b = viewportRect.bottom;
    final cx = (l + r) / 2;

    final rotCenter = ui.Offset(cx, t - _rotateOffsetPx);
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
  ///
  /// The bounding rect is always painted with [boxPaint] (callers may pass a
  /// transparent paint to suppress it). Knobs and the rotate affordance are
  /// hidden when `zoom < _minVisibleZoom`.
  static void paint({
    required ui.Canvas canvas,
    required ui.Rect viewportRect,
    required double zoom,
    required ui.Paint boxPaint,
    required ui.Paint knobFill,
    required ui.Paint knobStroke,
  }) {
    canvas.drawRect(viewportRect, boxPaint);
    if (!_handlesVisibleAt(zoom)) return;

    const half = _handleHalfPx;
    const cornerR = _knobCornerRadiusPx;

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

    final rot = ui.Offset(cx, t - _rotateOffsetPx);
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
      ..strokeWidth = _arcStrokeWidthPx;
    canvas.drawPath(arc, arcStroke);
  }
}
