part of 'infinite_canvas_controller.dart';

/// Selection, marquee, and hover state for [InfiniteCanvasController].
final class SelectionOps {
  SelectionOps(this._c);

  final InfiniteCanvasController _c;

  Set<int> get ids => Set.unmodifiable(_c._selectedQuadIds);

  int? get primaryId => _c._primaryQuadId;

  Iterable<CanvasNode> get nodes sync* {
    for (final id in _c._selectedQuadIds) {
      final n = _c._nodesByQuadId[id];
      if (n != null) yield n;
    }
  }

  CanvasNode? get primary =>
      _c._primaryQuadId != null ? _c._nodesByQuadId[_c._primaryQuadId] : null;

  ui.Rect? get unionBounds => _c.selectedUnionBounds;

  ui.Rect? get marqueeWorldRect => _c._marqueeWorldRect;

  int? get hoveredId => _c._hoveredQuadId;

  void clear() => _c.clearSelection();

  void setIds(Set<int> ids, {int? primary}) =>
      _c.setSelection(ids, primary: primary);

  void toggle(int quadId) => _c.toggleInSelection(quadId);

  void selectSingle(int quadId) => _c.selectSingle(quadId);

  void setHovered(int? id) => _c.setHoveredQuadId(id);

  void clearHover() => _c.clearHover();

  void beginMarquee(ui.Offset worldAnchor) {
    _c._marqueeAnchorWorld = worldAnchor;
    _c._marqueeWorldRect = ui.Rect.fromPoints(worldAnchor, worldAnchor);
    _c.invalidate();
  }

  void updateMarquee(ui.Offset world) {
    final anchor = _c._marqueeAnchorWorld;
    if (anchor == null) return;
    _c._marqueeWorldRect = _normalizeWorldRect(anchor, world);
    _c.invalidate();
  }

  void endMarquee({required bool additive, double minSizeWorld = 1e-6}) {
    final rect = _c._marqueeWorldRect;
    if (rect != null &&
        rect.width > minSizeWorld &&
        rect.height > minSizeWorld) {
      _c.applyMarquee(rect, additive: additive);
    } else {
      _c._marqueeWorldRect = null;
      _c._marqueeAnchorWorld = null;
      _c.invalidate();
    }
  }

  static ui.Rect _normalizeWorldRect(ui.Offset a, ui.Offset b) {
    return ui.Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }
}
