import 'dart:ui' as ui;

/// Maps [rect]’s edges from fractional coordinates inside [oldUnion] to the
/// same fractions inside [newUnion] (axis-aligned resize).
ui.Rect remapRectInsideUnion(ui.Rect rect, ui.Rect oldUnion, ui.Rect newUnion) {
  final ow = oldUnion.width;
  final oh = oldUnion.height;
  if (ow < 1e-9 || oh < 1e-9) return rect;
  final sx = newUnion.width / ow;
  final sy = newUnion.height / oh;
  return ui.Rect.fromLTWH(
    newUnion.left + (rect.left - oldUnion.left) * sx,
    newUnion.top + (rect.top - oldUnion.top) * sy,
    rect.width * sx,
    rect.height * sy,
  );
}
