part of 'infinite_canvas_controller.dart';

/// Node CRUD, grouping, spatial queries, and geometry mutations on [InfiniteCanvasController].
final class NodeOps {
  NodeOps(this._c);

  final InfiniteCanvasController _c;

  Iterable<CanvasNode> get all => _c._nodesByQuadId.values;

  Iterable<CanvasNode> get selected => _c.selection.nodes;

  CanvasNode? get primary => _c.selection.primary;

  CanvasNode? lookup(int quadId) => _c._nodesByQuadId[quadId];

  int add(CanvasNode node) => _c.addNode(node);

  void remove(int quadId) => _c.removeNode(quadId);

  /// Updates quadtree entry after [node.bounds] changed externally.
  void reindex(int quadId) => _c.updateNode(quadId);

  void reindexMany(Iterable<int> quadIds) => _c.relayoutNodes(quadIds);

  void rename(String name) {
    final id = _c._primaryQuadId;
    if (id == null) return;
    final node = _c._nodesByQuadId[id];
    if (node == null) return;
    node.label = name;
    _c.invalidate();
  }

  /// Applies [update] to each selected node whose style is an instance of [T].
  /// Returns how many nodes were updated.
  int applyStyle<T extends NodeStyle>(T Function(T) update) {
    var n = 0;
    for (final id in _c._selectedQuadIds) {
      final node = _c._nodesByQuadId[id];
      if (node == null) continue;
      final st = node.style;
      if (st is T) {
        node.style = update(st);
        _c.updateNode(id);
        n++;
      }
    }
    if (n > 0) _c.invalidate();
    return n;
  }

  void translate(Iterable<int> ids, ui.Offset deltaWorld) {
    for (final id in ids) {
      _c._nodesByQuadId[id]?.translateWorld(deltaWorld);
    }
    _c.relayoutNodes(ids);
  }

  void rotateAround(Iterable<int> ids, ui.Offset pivotWorld, double deltaRadians) {
    for (final id in ids) {
      _c._nodesByQuadId[id]?.rotateWorldAround(pivotWorld, deltaRadians);
    }
    _c.relayoutNodes(ids);
  }

  void resizeUnion({
    required ui.Rect oldUnion,
    required ui.Rect newUnion,
    required Map<int, ui.Rect> boundsSnapshot,
    required Iterable<int> ids,
  }) {
    for (final id in ids) {
      final snap = boundsSnapshot[id];
      final node = _c._nodesByQuadId[id];
      if (snap == null || node == null) continue;
      node.remapBoundsInUnion(snap, oldUnion, newUnion);
    }
    _c.relayoutNodes(ids);
  }

  /// Registers an atomic group of quad ids for higher-level app logic.
  void group(Iterable<int> ids) {
    final list = ids.where(_c._nodesByQuadId.containsKey).toList();
    if (list.length < 2) return;
    final gid = _c._nextGroupId++;
    _c._groups[gid] = list.toSet();
    for (final id in list) {
      _c._quadIdToGroup[id] = gid;
    }
    _c.invalidate();
  }

  void ungroup(int groupId) {
    final members = _c._groups.remove(groupId);
    if (members == null) return;
    for (final id in members) {
      _c._quadIdToGroup.remove(id);
    }
    _c.invalidate();
  }

  int? groupIdOf(int quadId) => _c._quadIdToGroup[quadId];

  int? hitTest(ui.Offset world, {double epsilonPixels = 4}) =>
      _c.pickTopNodeAtWorld(world, epsilonPixels: epsilonPixels);

  List<CanvasNode> visible({double inflate = 32}) =>
      _c.queryVisible(inflate: inflate);
}
