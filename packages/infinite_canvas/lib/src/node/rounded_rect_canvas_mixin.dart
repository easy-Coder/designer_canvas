import 'dart:math' as math;
import 'dart:ui' as ui;

import 'canvas_node.dart';

/// World-space axis-aligned rect geometry (with rotation), hit testing, and
/// transform hooks for [CanvasNode] subclasses. No painting — implement
/// [CanvasNode.draw] in the app (or test fixture).
///
/// Call [initRoundedRectGeometry] once from the subclass constructor before
/// [bounds] are read.
mixin RoundedRectCanvasMixin on CanvasNode {
  late ui.Offset _rrCenter;
  late double _rrWidth;
  late double _rrHeight;
  late double _rrRotation;

  double _sessionW = 0;
  double _sessionH = 0;
  ui.Offset _sessionCenter = ui.Offset.zero;
  double _sessionRot = 0;
  bool _hasSession = false;

  void initRoundedRectGeometry({
    required ui.Offset center,
    required double width,
    required double height,
    double rotationRadians = 0,
  }) {
    _rrCenter = center;
    _rrWidth = width;
    _rrHeight = height;
    _rrRotation = rotationRadians;
  }

  ui.Offset get rectCenter => _rrCenter;
  double get rectWidth => _rrWidth;
  double get rectHeight => _rrHeight;

  double get _halfW => _rrWidth / 2;
  double get _halfH => _rrHeight / 2;

  @override
  double get rotationRadians => _rrRotation;

  @override
  ui.Offset get transformPivot => _rrCenter;

  @override
  ui.Rect get bounds {
    if (_rrRotation == 0) {
      return ui.Rect.fromCenter(
        center: _rrCenter,
        width: _rrWidth,
        height: _rrHeight,
      );
    }
    final c = math.cos(_rrRotation);
    final s = math.sin(_rrRotation);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final lx in <double>[-_halfW, _halfW]) {
      for (final ly in <double>[-_halfH, _halfH]) {
        final wx = _rrCenter.dx + lx * c - ly * s;
        final wy = _rrCenter.dy + lx * s + ly * c;
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
    if (_rrRotation == 0) {
      return bounds.contains(world);
    }
    final c = math.cos(-_rrRotation);
    final s = math.sin(-_rrRotation);
    final dx = world.dx - _rrCenter.dx;
    final dy = world.dy - _rrCenter.dy;
    final lx = dx * c - dy * s;
    final ly = dx * s + dy * c;
    return lx.abs() <= _halfW + 1e-9 && ly.abs() <= _halfH + 1e-9;
  }

  @override
  void beginTransformSession() {
    _sessionW = _rrWidth;
    _sessionH = _rrHeight;
    _sessionCenter = _rrCenter;
    _sessionRot = _rrRotation;
    _hasSession = true;
  }

  @override
  void endTransformSession() {
    _hasSession = false;
  }

  @override
  void translateWorld(ui.Offset deltaWorld) {
    _rrCenter += deltaWorld;
  }

  @override
  void rotateWorldAround(ui.Offset pivotWorld, double deltaRadians) {
    final c0 = math.cos(deltaRadians);
    final s0 = math.sin(deltaRadians);
    final dx = _rrCenter.dx - pivotWorld.dx;
    final dy = _rrCenter.dy - pivotWorld.dy;
    _rrCenter = ui.Offset(
      pivotWorld.dx + dx * c0 - dy * s0,
      pivotWorld.dy + dx * s0 + dy * c0,
    );
    _rrRotation += deltaRadians;
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
    _rrCenter = ui.Offset(tcx, tcy);

    _rrWidth = (_sessionW * newUnion.width / ow).clamp(1e-6, double.infinity);
    _rrHeight = (_sessionH * newUnion.height / oh).clamp(1e-6, double.infinity);
    _rrRotation = _sessionRot;
  }
}
