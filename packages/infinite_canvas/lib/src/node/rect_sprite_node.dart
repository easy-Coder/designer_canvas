import 'dart:math' as math;
import 'dart:ui' as ui;

import 'canvas_node.dart';
import 'canvas_paint_context.dart';

/// Axis-aligned rounded rectangle in world space with optional rotation about
/// its [center]. [bounds] is the tight axis-aligned bounding box of the
/// rotated shape (for the quadtree and selection union).
class RectSpriteNode extends CanvasNode {
  RectSpriteNode({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
    required this.color,
    this.cornerRadiusWorld = 8,
    this.zIndexValue = 1,
  })  : _center = center,
        _width = width,
        _height = height,
        _rotation = rotationRadians;

  ui.Offset _center;
  double _width;
  double _height;
  double _rotation;

  @override
  double get rotationRadians => _rotation;

  final ui.Color color;

  /// Corner radius in **world** units (before camera).
  final double cornerRadiusWorld;

  final int zIndexValue;

  ui.Offset get center => _center;

  double get width => _width;

  double get height => _height;

  double get _halfW => _width / 2;

  double get _halfH => _height / 2;

  @override
  int get zIndex => zIndexValue;

  @override
  ui.Offset get transformPivot => _center;

  @override
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

  @override
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

  double _sessionW = 0;
  double _sessionH = 0;
  ui.Offset _sessionCenter = ui.Offset.zero;
  double _sessionRot = 0;
  bool _hasSession = false;

  @override
  void beginTransformSession() {
    _sessionW = _width;
    _sessionH = _height;
    _sessionCenter = _center;
    _sessionRot = _rotation;
    _hasSession = true;
  }

  @override
  void translateWorld(ui.Offset deltaWorld) {
    _center += deltaWorld;
  }

  @override
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

  @override
  void endTransformSession() {
    _hasSession = false;
  }

  @override
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

  @override
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
}
