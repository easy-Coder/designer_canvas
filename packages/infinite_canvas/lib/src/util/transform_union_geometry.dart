import 'dart:math' as math;
import 'dart:ui' as ui;

import '../selection/selection_handles.dart';

/// Computes a new selection union from a fixed anchor and pointer during
/// handle drags.
ui.Rect unionForHandleDrag({
  required SelectionHandleKind kind,
  required ui.Rect startUnion,
  required ui.Offset pointerWorld,
  required double minWidth,
  required double minHeight,
}) {
  final l0 = startUnion.left;
  final t0 = startUnion.top;
  final r0 = startUnion.right;
  final b0 = startUnion.bottom;

  switch (kind) {
    case SelectionHandleKind.topLeft:
      return ui.Rect.fromLTRB(
        math.min(pointerWorld.dx, r0 - minWidth),
        math.min(pointerWorld.dy, b0 - minHeight),
        r0,
        b0,
      );
    case SelectionHandleKind.topRight:
      return ui.Rect.fromLTRB(
        l0,
        math.min(pointerWorld.dy, b0 - minHeight),
        math.max(pointerWorld.dx, l0 + minWidth),
        b0,
      );
    case SelectionHandleKind.bottomRight:
      return ui.Rect.fromLTRB(
        l0,
        t0,
        math.max(pointerWorld.dx, l0 + minWidth),
        math.max(pointerWorld.dy, t0 + minHeight),
      );
    case SelectionHandleKind.bottomLeft:
      return ui.Rect.fromLTRB(
        math.min(pointerWorld.dx, r0 - minWidth),
        t0,
        r0,
        math.max(pointerWorld.dy, t0 + minHeight),
      );
    case SelectionHandleKind.top:
      return ui.Rect.fromLTRB(
        l0,
        math.min(pointerWorld.dy, b0 - minHeight),
        r0,
        b0,
      );
    case SelectionHandleKind.bottom:
      return ui.Rect.fromLTRB(
        l0,
        t0,
        r0,
        math.max(pointerWorld.dy, t0 + minHeight),
      );
    case SelectionHandleKind.left:
      return ui.Rect.fromLTRB(
        math.min(pointerWorld.dx, r0 - minWidth),
        t0,
        r0,
        b0,
      );
    case SelectionHandleKind.right:
      return ui.Rect.fromLTRB(
        l0,
        t0,
        math.max(pointerWorld.dx, l0 + minWidth),
        b0,
      );
    case SelectionHandleKind.rotate:
      return startUnion;
  }
}
