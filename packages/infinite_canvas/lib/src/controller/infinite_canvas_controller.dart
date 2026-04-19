import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:repaint/repaint.dart';

import '../camera/camera.dart';
import '../node/canvas_node.dart';

/// Owns the [Camera], [QuadTree] spatial index, and [CanvasNode] instances.
class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    Camera? camera,
    required this.worldBounds,
    int quadtreeCapacity = 24,
    int quadtreeDepth = 12,
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

  Iterable<CanvasNode> get nodes => _nodesByQuadId.values;

  void _onCameraChanged() => notifyListeners();

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
