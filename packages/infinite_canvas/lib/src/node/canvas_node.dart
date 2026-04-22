import 'dart:ui' as ui;

import 'canvas_paint_context.dart';
import 'node_style.dart';

/// Base class for drawable objects in world space.
///
/// Subclasses supply [bounds] (axis-aligned, world coordinates). The
/// quadtree uses [bounds]; set [zIndex] via the constructor for paint order
/// among overlapping nodes.
///
/// Override [draw] to paint; you may call `super.draw` first for shared base
/// behavior (default is a no-op).
///
/// **Interactive transforms** (used by [DefaultInfiniteCanvasGestureHandler]
/// when [InfiniteCanvasGestureConfig.enableNodeTransform] is true): override
/// [translateWorld], [rotateWorldAround], and [remapBoundsInUnion] to mutate
/// geometry; call [InfiniteCanvasController.relayoutNodes] after changes.
/// Defaults are no-ops so static or non-resizable nodes need no code.
///
/// **Union handle resize:** [remapBoundsInUnion] receives this node’s
/// [bounds] snapshot from when the drag committed ([beginTransformSession] /
/// baseline). Non-rect shapes should map that AABB change onto their own
/// parameters (e.g. uniform scale for a circle from union width/height ratios).
///
/// Shared axis-aligned frame geometry (with rotation) and transforms (no
/// painting): [RoundedRectCanvasMixin]. Subclasses implement [draw] for
/// different visuals inside the same world-space frame.
abstract class CanvasNode {
  CanvasNode({
    this.zIndex = 0,
    NodeStyle? style,
    String? label,
  })  : _style = style ?? const BasicNodeStyle(),
        label = label ?? 'Node';

  /// Lower values are drawn first; higher values paint on top.
  final int zIndex;

  NodeStyle _style;

  /// Common node style contract. Concrete nodes may enforce subtype guards.
  // ignore: unnecessary_getters_setters
  NodeStyle get style => _style;

  // ignore: unnecessary_getters_setters
  set style(NodeStyle value) {
    _style = value;
  }

  /// User-facing node name shown in sidebars/inspectors.
  String label;

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
  /// oriented shape.
  bool containsWorldPoint(ui.Offset world) => bounds.contains(world);

  /// Extra scale in **world** space for authored local content (1 = default).
  double get worldScale => 1;

  /// Draw this node. Use [context.worldRectToViewport] (and related helpers)
  /// so geometry lines up with [CameraView] transforms.
  ///
  /// Default is empty; subclasses override. Call `super.draw` first if you rely
  /// on future shared drawing hooks on [CanvasNode].
  void draw(ui.Canvas canvas, CanvasPaintContext context) {}

  /// Called once when a transform drag (scale / rotate) commits past slop.
  ///
  /// Implementations that need stable drag baselines should snapshot geometry
  /// here before [remapBoundsInUnion] runs.
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
