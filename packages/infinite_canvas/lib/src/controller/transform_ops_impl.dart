part of 'infinite_canvas_controller.dart';

/// Transform handle drag / rotate sessions (state previously in [DefaultInfiniteCanvasGestureHandler]).
final class TransformOps {
  TransformOps(this._c);

  final InfiniteCanvasController _c;

  SelectionHandleKind? activeHandleKind;

  ui.Rect? _transformStartUnion;
  Map<int, ui.Rect>? _boundsSnapshot;
  ui.Offset? _rotatePointerWorldLast;
  bool _baselinePrepared = false;

  SelectionHandleKind? hitHandle({
    required ui.Offset local,
    required double zoom,
  }) {
    final union = _c.selectedUnionBounds;
    if (union == null) return null;
    final vr = _c.camera.globalToLocalRect(union);
    return SelectionHandles.hitTest(
      viewportRect: vr,
      local: local,
      zoom: zoom,
    );
  }

  void beginHandleDrag(
    SelectionHandleKind kind, {
    required ui.Offset pointerWorld,
  }) {
    activeHandleKind = kind;
    _baselinePrepared = false;
    _transformStartUnion = null;
    _boundsSnapshot = null;
    _rotatePointerWorldLast = null;
  }

  void _prepareBaseline() {
    if (_baselinePrepared) return;
    final union = _c.selectedUnionBounds;
    if (union == null) {
      _baselinePrepared = true;
      return;
    }
    _baselinePrepared = true;
    _transformStartUnion = union;
    _boundsSnapshot = {
      for (final id in _c._selectedQuadIds)
        id: _c._nodesByQuadId[id]!.bounds,
    };
    if (activeHandleKind != SelectionHandleKind.rotate) {
      for (final id in _c._selectedQuadIds) {
        _c._nodesByQuadId[id]?.beginTransformSession();
      }
    }
  }

  void updateHandleDrag({
    required ui.Offset pointerWorld,
    double minUnionSizeWorld = 1.0,
  }) {
    final kind = activeHandleKind;
    if (kind == null || kind == SelectionHandleKind.rotate) return;
    _prepareBaseline();
    final startUnion = _transformStartUnion;
    final snapshot = _boundsSnapshot;
    if (startUnion == null || snapshot == null) return;

    final newUnion = unionForHandleDrag(
      kind: kind,
      startUnion: startUnion,
      pointerWorld: pointerWorld,
      minWidth: minUnionSizeWorld,
      minHeight: minUnionSizeWorld,
    );
    _c.node.resizeUnion(
      oldUnion: startUnion,
      newUnion: newUnion,
      boundsSnapshot: snapshot,
      ids: _c._selectedQuadIds,
    );
  }

  void beginRotate(ui.Offset pointerWorld) {
    activeHandleKind = SelectionHandleKind.rotate;
    _baselinePrepared = false;
    _transformStartUnion = _c.selectedUnionBounds;
    _boundsSnapshot = null;
    _rotatePointerWorldLast = null;
    _prepareBaseline();
    _rotatePointerWorldLast = pointerWorld;
  }

  void updateRotate(ui.Offset pointerWorld) {
    final union = _transformStartUnion;
    if (union == null) return;
    final last = _rotatePointerWorldLast;
    if (last == null) {
      _rotatePointerWorldLast = pointerWorld;
      return;
    }
    final center = union.center;
    final v0 = last - center;
    final v1 = pointerWorld - center;
    if (v0.distance > 1e-9 && v1.distance > 1e-9) {
      final cross = v0.dx * v1.dy - v0.dy * v1.dx;
      final dot = v0.dx * v1.dx + v0.dy * v1.dy;
      final delta = math.atan2(cross, dot);
      for (final id in _c._selectedQuadIds) {
        _c._nodesByQuadId[id]?.rotateWorldAround(center, delta);
      }
      _c.relayoutNodes(_c._selectedQuadIds);
    }
    _rotatePointerWorldLast = pointerWorld;
  }

  void end() {
    for (final id in _c._selectedQuadIds) {
      _c._nodesByQuadId[id]?.endTransformSession();
    }
    activeHandleKind = null;
    _baselinePrepared = false;
    _transformStartUnion = null;
    _boundsSnapshot = null;
    _rotatePointerWorldLast = null;
    _c.invalidate();
  }
}
