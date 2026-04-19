import 'dart:ui' as ui;

import 'canvas_paint_context.dart';

/// Base class for drawable objects in world space.
///
/// Subclasses provide [bounds] (axis-aligned, world coordinates) and
/// implement [draw]. The quadtree uses [bounds]; override [zIndex] for paint
/// order among overlapping nodes.
abstract class CanvasNode {
  CanvasNode();

  /// World-space axis-aligned bounds used for culling and spatial indexing.
  ui.Rect get bounds;

  /// Hit testing in world space (defaults to [bounds.contains]).
  bool containsWorldPoint(ui.Offset world) => bounds.contains(world);

  /// Lower values are drawn first; higher values paint on top.
  int get zIndex => 0;

  /// Extra scale in **world** space for authored local content (1 = default).
  double get worldScale => 1;

  /// Draw this node. Use [context.worldRectToViewport] (and related helpers)
  /// so geometry lines up with [CameraView] transforms.
  void draw(ui.Canvas canvas, CanvasPaintContext context);
}
