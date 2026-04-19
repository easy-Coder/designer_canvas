import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:repaint/repaint.dart';

import '../camera/camera.dart';
import '../node/canvas_node.dart';

/// Called when the user double-clicks a node (see [DefaultInfiniteCanvasGestureHandler]).
typedef NodeDoubleClickCallback = void Function(int quadId, CanvasNode node);

/// Owns the [Camera], [QuadTree] spatial index, [CanvasNode] instances, and
/// selection state.
class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    Camera? camera,
    required this.worldBounds,
    int quadtreeCapacity = 24,
    int quadtreeDepth = 12,
    this.onNodeDoubleClick,
  })  : _ownsCamera = camera == null,
        _camera = camera ?? Camera(),
        quadTree = QuadTree(
          boundary: worldBounds,
          capacity: quadtreeCapacity,
          depth: quadtreeDepth,
        ) {
    _camera.addListener(_onCameraChanged);
  }

  final bool _ownsCamera;

  /// Axis-aligned world extent used by the quadtree. Objects should stay
  /// inside this region for indexing to remain valid.
  final ui.Rect worldBounds;

  final Camera _camera;

  Camera get camera => _camera;

  final QuadTree quadTree;

  final Map<int, CanvasNode> _nodesByQuadId = {};

  /// Optional hook for future node-type actions (editors, inspectors, etc.).
  final NodeDoubleClickCallback? onNodeDoubleClick;

  final Set<int> _selectedQuadIds = {};
  int? _primaryQuadId;
  ui.Rect? _marqueeWorldRect;

  Set<int> get selectedQuadIds => Set.unmodifiable(_selectedQuadIds);

  int? get primaryQuadId => _primaryQuadId;

  CanvasNode? get primaryNode =>
      _primaryQuadId != null ? _nodesByQuadId[_primaryQuadId] : null;

  /// Axis-aligned union of every selected node’s [CanvasNode.bounds] in world
  /// space. Null when nothing is selected or all ids are stale.
  ui.Rect? get selectedUnionBounds {
    if (_selectedQuadIds.isEmpty) return null;
    ui.Rect? u;
    for (final id in _selectedQuadIds) {
      final n = _nodesByQuadId[id];
      if (n == null) continue;
      final r = n.bounds;
      u = u == null ? r : u.expandToInclude(r);
    }
    return u;
  }

  ui.Rect? get marqueeWorldRect => _marqueeWorldRect;

  set marqueeWorldRect(ui.Rect? value) {
    if (_marqueeWorldRect == value) return;
    _marqueeWorldRect = value;
    notifyListeners();
  }

  Iterable<CanvasNode> get nodes => _nodesByQuadId.values;

  /// Node for a quadtree id, if present.
  CanvasNode? lookupNode(int quadId) => _nodesByQuadId[quadId];

  void _onCameraChanged() => notifyListeners();

  void _notifySelection() => notifyListeners();

  /// Notifies listeners so the canvas repaints (used after noop handle / node drags).
  void requestRepaint() => notifyListeners();

  void clearSelection() {
    if (_selectedQuadIds.isEmpty && _primaryQuadId == null) return;
    _selectedQuadIds.clear();
    _primaryQuadId = null;
    _notifySelection();
  }

  void setSelection(Set<int> ids, {int? primary}) {
    _selectedQuadIds
      ..clear()
      ..addAll(ids);
    _primaryQuadId = primary ?? (ids.isEmpty ? null : _pickPrimaryFrom(ids));
    _notifySelection();
  }

  void toggleInSelection(int quadId) {
    if (!_nodesByQuadId.containsKey(quadId)) return;
    if (_selectedQuadIds.contains(quadId)) {
      _selectedQuadIds.remove(quadId);
      if (_primaryQuadId == quadId) {
        _primaryQuadId =
            _selectedQuadIds.isEmpty ? null : _pickPrimaryFrom(_selectedQuadIds);
      }
    } else {
      _selectedQuadIds.add(quadId);
      _primaryQuadId = quadId;
    }
    _notifySelection();
  }

  /// Select exactly one node (clears previous selection).
  void selectSingle(int quadId) {
    if (!_nodesByQuadId.containsKey(quadId)) return;
    _selectedQuadIds
      ..clear()
      ..add(quadId);
    _primaryQuadId = quadId;
    _notifySelection();
  }

  /// Replaces or unions the selection with nodes whose bounds intersect [worldRect].
  void applyMarquee(ui.Rect worldRect, {required bool additive}) {
    final ids = quadTree.queryIds(worldRect);
    final hit = <int>{};
    for (final id in ids) {
      if (_nodesByQuadId.containsKey(id)) hit.add(id);
    }
    if (additive) {
      _selectedQuadIds.addAll(hit);
    } else {
      _selectedQuadIds
        ..clear()
        ..addAll(hit);
    }
    _primaryQuadId =
        _selectedQuadIds.isEmpty ? null : _pickPrimaryFrom(_selectedQuadIds);
    _marqueeWorldRect = null;
    _notifySelection();
  }

  int _pickPrimaryFrom(Set<int> ids) {
    var bestId = ids.first;
    var bestZ = _nodesByQuadId[bestId]?.zIndex ?? 0;
    for (final id in ids) {
      final z = _nodesByQuadId[id]?.zIndex ?? 0;
      if (z > bestZ || (z == bestZ && id < bestId)) {
        bestZ = z;
        bestId = id;
      }
    }
    return bestId;
  }

  /// Top-most node under [world] (by [CanvasNode.zIndex]), or null.
  int? pickTopNodeAtWorld(ui.Offset world, {double epsilonPixels = 4}) {
    final cam = camera;
    final ez = epsilonPixels / cam.zoomDouble;
    final probe = ui.Rect.fromCircle(center: world, radius: ez);
    final ids = quadTree.queryIds(probe);
    final candidates = <int>[];
    for (final id in ids) {
      final n = _nodesByQuadId[id];
      if (n != null && n.containsWorldPoint(world)) candidates.add(id);
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final za = _nodesByQuadId[a]!.zIndex;
      final zb = _nodesByQuadId[b]!.zIndex;
      final c = zb.compareTo(za);
      if (c != 0) return c;
      return a.compareTo(b);
    });
    return candidates.first;
  }

  /// Inserts [node] using [node.bounds]; returns the quadtree object id.
  int addNode(CanvasNode node) {
    final id = quadTree.insert(node.bounds);
    _nodesByQuadId[id] = node;
    notifyListeners();
    return id;
  }

  /// Removes the node associated with [quadId].
  void removeNode(int quadId) {
    if (!_nodesByQuadId.containsKey(quadId)) return;
    quadTree.remove(quadId);
    _nodesByQuadId.remove(quadId);
    _selectedQuadIds.remove(quadId);
    if (_primaryQuadId == quadId) {
      _primaryQuadId = _selectedQuadIds.isEmpty
          ? null
          : _pickPrimaryFrom(_selectedQuadIds);
    }
    notifyListeners();
  }

  /// Updates the quadtree from the current [CanvasNode.bounds] (after the node
  /// moved or resized).
  void updateNode(int quadId) {
    final node = _nodesByQuadId[quadId];
    if (node == null) return;
    final r = node.bounds;
    quadTree.move(
      quadId,
      r.left,
      r.top,
      width: r.width,
      height: r.height,
    );
    notifyListeners();
  }

  /// Nodes whose bounds intersect the visible world rect, optionally inflated
  /// to reduce edge pop-in (see PlugFox article).
  List<CanvasNode> queryVisible({double inflate = 32}) {
    final rect = camera.bound.inflate(inflate);
    final ids = quadTree.queryIds(rect);
    final out = <CanvasNode>[];
    for (final id in ids) {
      final n = _nodesByQuadId[id];
      if (n != null) out.add(n);
    }
    out.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return out;
  }

  @override
  void dispose() {
    _camera.removeListener(_onCameraChanged);
    if (_ownsCamera) {
      _camera.dispose();
    }
    super.dispose();
  }
}
