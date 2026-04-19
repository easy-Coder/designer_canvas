import 'dart:ui' as ui;

import 'canvas_paint_context.dart';

/// Base class for drawable objects in world space.
///
/// Subclasses provide [bounds] (axis-aligned, world coordinates) and
/// implement [draw]. The quadtree uses [bounds]; override [zIndex] for paint
/// order among overlapping nodes.
///
/// **Interactive transforms** (used by [DefaultInfiniteCanvasGestureHandler]
/// when [InfiniteCanvasGestureConfig.enableNodeTransform] is true): override
/// [translateWorld], [rotateWorldAround], and [remapBoundsInUnion] to mutate
/// geometry; call [InfiniteCanvasController.relayoutNodes] after changes.
/// Defaults are no-ops so existing node types stay static.
abstract class CanvasNode {
  CanvasNode();

  /// World-space axis-aligned bounds used for culling and spatial indexing.
  ui.Rect get bounds;

  /// World rotation in radians about [transformPivot] (default 0).
  double get rotationRadians => 0;

  /// Pivot for [rotationRadians] and inverse hit testing (defaults to bounds
  /// center; may differ if [bounds] is an expanded AABB).
  ui.Offset get transformPivot => bounds.center;

  /// Hit testing in world space (axis-aligned [bounds] by default).
  ///
  /// Nodes with non-zero [rotationRadians] should override and test the
  /// oriented shape (see [RectSpriteNode.containsWorldPoint]).
  bool containsWorldPoint(ui.Offset world) => bounds.contains(world);

  /// Lower values are drawn first; higher values paint on top.
  int get zIndex => 0;

  /// Extra scale in **world** space for authored local content (1 = default).
  double get worldScale => 1;

  /// Draw this node. Use [context.worldRectToViewport] (and related helpers)
  /// so geometry lines up with [CameraView] transforms.
  void draw(ui.Canvas canvas, CanvasPaintContext context);

  /// Called once when a transform drag (scale / rotate) commits past slop.
  ///
  /// Implementations that need stable drag baselines (e.g. [RectSpriteNode])
  /// should snapshot geometry here before [remapBoundsInUnion] runs.
  void beginTransformSession() {}

  /// Clears any drag baseline state from [beginTransformSession].
  void endTransformSession() {}

  /// Translates this node by [deltaWorld] during a drag.
  void translateWorld(ui.Offset deltaWorld) {}

  /// Rotates this node by [deltaRadians] around [pivotWorld] (rigid motion).
  void rotateWorldAround(ui.Offset pivotWorld, double deltaRadians) {}

  /// Maps this node’s geometry from [startBounds] inside [oldUnion] to the
  /// same normalized position/size inside [newUnion] (axis-aligned group
  /// resize). [startBounds] must be this node’s [bounds] snapshot taken when
  /// the transform drag committed (see [beginTransformSession]).
  void remapBoundsInUnion(
    ui.Rect startBounds,
    ui.Rect oldUnion,
    ui.Rect newUnion,
  ) {}
}
