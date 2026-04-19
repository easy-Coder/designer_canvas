import 'dart:math' as math;
import 'dart:ui' as ui;

import 'canvas_paint_context.dart';

/// Rounded rectangle in world space with optional rotation about [center].
///
/// [bounds] is the tight axis-aligned bounding box of the rotated shape (for
/// the quadtree and selection union). Supports interactive transforms via
/// [translateWorld], [rotateWorldAround], and [remapBoundsInUnion] (used by
/// [DefaultInfiniteCanvasGestureHandler] when
/// [InfiniteCanvasGestureConfig.enableNodeTransform] is true).
final class CanvasNode {
  CanvasNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    required this.color,
    this.cornerRadiusWorld = 8,
    this.zIndex = 1,
  })  : _center = center,
        _width = width,
        _height = height,
        _rotation = rotationRadians;

  /// Axis-aligned [rect] in world space, no rotation.
  factory CanvasNode.fromAxisAlignedRect(
    ui.Rect rect, {
    ui.Color color = const ui.Color(0x00000000),
    double cornerRadiusWorld = 8,
    int zIndex = 0,
  }) {
    return CanvasNode(
      center: rect.center,
      width: rect.width,
      height: rect.height,
      rotationRadians: 0,
      color: color,
      cornerRadiusWorld: cornerRadiusWorld,
      zIndex: zIndex,
    );
  }

  ui.Offset _center;
  double _width;
  double _height;
  double _rotation;

  /// Fill color for the rounded rect.
  final ui.Color color;

  /// Corner radius in **world** units (before camera).
  final double cornerRadiusWorld;

  /// Lower values are drawn first; higher values paint on top.
  final int zIndex;

  ui.Offset get center => _center;

  double get width => _width;

  double get height => _height;

  double get _halfW => _width / 2;

  double get _halfH => _height / 2;

  /// World rotation in radians about [transformPivot].
  double get rotationRadians => _rotation;

  /// Pivot for [rotationRadians] and inverse hit testing.
  ui.Offset get transformPivot => _center;

  /// World-space axis-aligned bounds used for culling and spatial indexing.
  ui.Rect get bounds {
    if (_rotation == 0) {
      return ui.Rect.fromCenter(
        center: _center,
        width: _width,
        height: _height,
      );
    }
    final c = math.cos(_rotation);
    final s = math.sin(_rotation);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final lx in <double>[-_halfW, _halfW]) {
      for (final ly in <double>[-_halfH, _halfH]) {
        final wx = _center.dx + lx * c - ly * s;
        final wy = _center.dy + lx * s + ly * c;
        minX = math.min(minX, wx);
        minY = math.min(minY, wy);
        maxX = math.max(maxX, wx);
        maxY = math.max(maxY, wy);
      }
    }
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Hit testing in world space (oriented rect when [rotationRadians] ≠ 0).
  bool containsWorldPoint(ui.Offset world) {
    if (_rotation == 0) {
      return bounds.contains(world);
    }
    final c = math.cos(-_rotation);
    final s = math.sin(-_rotation);
    final dx = world.dx - _center.dx;
    final dy = world.dy - _center.dy;
    final lx = dx * c - dy * s;
    final ly = dx * s + dy * c;
    return lx.abs() <= _halfW + 1e-9 && ly.abs() <= _halfH + 1e-9;
  }

  /// Extra scale in **world** space for authored local content (1 = default).
  double get worldScale => 1;

  /// Draw this node. Use [context.worldRectToViewport] (and related helpers)
  /// so geometry lines up with [CameraView] transforms.
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    final pivot = context.camera.globalToLocal(_center.dx, _center.dy);
    final hw = _halfW * context.camera.zoomDouble;
    final hh = _halfH * context.camera.zoomDouble;
    final rPx = cornerRadiusWorld * context.camera.zoomDouble;
    final local = ui.RRect.fromRectXY(
      ui.Rect.fromLTWH(-hw, -hh, hw * 2, hh * 2),
      rPx,
      rPx,
    );

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(_rotation);
    final fill = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(local, fill);
    canvas.restore();
  }

  double _sessionW = 0;
  double _sessionH = 0;
  ui.Offset _sessionCenter = ui.Offset.zero;
  double _sessionRot = 0;
  bool _hasSession = false;

  /// Called once when a transform drag (scale / rotate) commits past slop.
  ///
  /// Snapshots geometry before [remapBoundsInUnion] runs.
  void beginTransformSession() {
    _sessionW = _width;
    _sessionH = _height;
    _sessionCenter = _center;
    _sessionRot = _rotation;
    _hasSession = true;
  }

  /// Clears any drag baseline state from [beginTransformSession].
  void endTransformSession() {
    _hasSession = false;
  }

  /// Translates this node by [deltaWorld] during a drag.
  void translateWorld(ui.Offset deltaWorld) {
    _center += deltaWorld;
  }

  /// Rotates this node by [deltaRadians] around [pivotWorld] (rigid motion).
  void rotateWorldAround(ui.Offset pivotWorld, double deltaRadians) {
    final c0 = math.cos(deltaRadians);
    final s0 = math.sin(deltaRadians);
    final dx = _center.dx - pivotWorld.dx;
    final dy = _center.dy - pivotWorld.dy;
    _center = ui.Offset(
      pivotWorld.dx + dx * c0 - dy * s0,
      pivotWorld.dy + dx * s0 + dy * c0,
    );
    _rotation += deltaRadians;
  }

  /// Maps this node’s geometry from [startBounds] inside [oldUnion] to the
  /// same normalized position/size inside [newUnion] (axis-aligned group
  /// resize). [startBounds] must be this node’s [bounds] snapshot taken when
  /// the transform drag committed (see [beginTransformSession]).
  void remapBoundsInUnion(
    ui.Rect startBounds,
    ui.Rect oldUnion,
    ui.Rect newUnion,
  ) {
    if (!_hasSession) return;
    if (startBounds.shortestSide < 0) return;
    final ow = oldUnion.width;
    final oh = oldUnion.height;
    if (ow < 1e-9 || oh < 1e-9) return;

    final cx = _sessionCenter.dx;
    final cy = _sessionCenter.dy;
    final tcx =
        newUnion.left + (cx - oldUnion.left) / ow * newUnion.width;
    final tcy =
        newUnion.top + (cy - oldUnion.top) / oh * newUnion.height;
    _center = ui.Offset(tcx, tcy);

    _width = (_sessionW * newUnion.width / ow).clamp(1e-6, double.infinity);
    _height = (_sessionH * newUnion.height / oh).clamp(1e-6, double.infinity);
    _rotation = _sessionRot;
  }
}
