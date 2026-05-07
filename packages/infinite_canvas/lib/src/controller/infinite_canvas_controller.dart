import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:repaint/repaint.dart';

import '../camera/camera.dart';
import '../camera/camera_view.dart';
import '../node/canvas_node.dart';
import '../node/node_style.dart';
import '../selection/selection_handles.dart';
import '../text/canvas_text_ime_client.dart';
import '../text/canvas_text_ops.dart' as tex;
import '../text/text_attribute_toggleable.dart';
import '../text/text_ops_mixin.dart';
import '../util/transform_union_geometry.dart';

part 'selection_ops_impl.dart';
part 'node_ops_impl.dart';
part 'transform_ops_impl.dart';
part 'canvas_text_ops_impl.dart';

/// Called when the user double-clicks a node (app handles tool activation).
typedef NodeDoubleClickCallback = void Function(int quadId, CanvasNode node);

/// Owns the [Camera], [QuadTree], [CanvasNode] instances, selection,
/// transform sessions, and inline text editing ([CanvasTextOps]).
///
/// Mutating namespace methods notify listeners; do not call [notifyListeners]
/// from app code for routine updates.
class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    Camera? camera,
    this.onNodeDoubleClick,
  })  : _ownsCamera = camera == null,
        _worldBounds = _kDefaultWorldBounds,
        quadTree = QuadTree(
          boundary: _kDefaultWorldBounds,
          capacity: 24,
          depth: 12,
        ),
        _camera = camera ?? Camera() {
    _camera.addListener(_onCameraChanged);
    selection = SelectionOps(this);
    node = NodeOps(this);
    transform = TransformOps(this);
    text = CanvasTextOps(this);
  }

  /// Default axis-aligned world extent for the quadtree (matches typical editor canvas).
  static final ui.Rect _kDefaultWorldBounds =
      ui.Rect.fromLTWH(-10000, -10000, 20000, 20000);

  late final SelectionOps selection;
  late final NodeOps node;
  late final TransformOps transform;
  late final CanvasTextOps text;

  /// Current quadtree boundary (axis-aligned world extent).
  ui.Rect _worldBounds;

  ui.Rect get worldBounds => _worldBounds;

  /// Rebuilds the quadtree for a new world extent and reinserts all nodes.
  ///
  /// Quad ids are regenerated; clear app-level quad id maps and rebuild from
  /// document if needed.
  void setWorldBounds(
    ui.Rect rect, {
    int capacity = 24,
    int depth = 12,
  }) {
    _worldBounds = rect;
    final entries = _nodesByQuadId.entries.toList(growable: false);
    _nodesByQuadId.clear();
    _selectedQuadIds.clear();
    _primaryQuadId = null;
    _hoveredQuadId = null;
    _marqueeWorldRect = null;
    _marqueeAnchorWorld = null;
    _clearGroups();
    quadTree = QuadTree(
      boundary: rect,
      capacity: capacity,
      depth: depth,
    );
    for (final e in entries) {
      final id = quadTree.insert(e.value.bounds);
      _nodesByQuadId[id] = e.value;
    }
    notifyListeners();
  }

  bool _ownsCamera;

  Camera _camera;

  /// Active camera (see [setCamera]).
  Camera get camera => _camera;

  /// Replaces the camera. Disposes the previous camera when this controller
  /// constructed without passing one in.
  void setCamera(Camera value) {
    _camera.removeListener(_onCameraChanged);
    if (_ownsCamera) {
      _camera.dispose();
    }
    _camera = value;
    _ownsCamera = true;
    _camera.addListener(_onCameraChanged);
    notifyListeners();
  }

  QuadTree quadTree;

  final Map<int, CanvasNode> _nodesByQuadId = {};

  final NodeDoubleClickCallback? onNodeDoubleClick;

  int? _hoveredQuadId;

  /// Quad id under the pointer for hover highlight (select mode).
  int? get hoveredQuadId => _hoveredQuadId;

  /// Anchor for in-progress marquee selection ([SelectionOps.beginMarquee]).
  ui.Offset? _marqueeAnchorWorld;

  /// Notifies canvas listeners after model changes (used by [NodeOps], [CanvasTextOps], etc.).
  void invalidate() => notifyListeners();

  int _nextGroupId = 1;
  final Map<int, Set<int>> _groups = {};
  final Map<int, int> _quadIdToGroup = {};

  void _clearGroups() {
    _groups.clear();
    _quadIdToGroup.clear();
    _nextGroupId = 1;
  }

  final Set<int> _selectedQuadIds = {};
  int? _primaryQuadId;
  ui.Rect? _marqueeWorldRect;

  Set<int> get selectedQuadIds => Set.unmodifiable(_selectedQuadIds);

  int? get primaryQuadId => _primaryQuadId;

  CanvasNode? get primaryNode =>
      _primaryQuadId != null ? _nodesByQuadId[_primaryQuadId] : null;

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
    if (value == null) _marqueeAnchorWorld = null;
    notifyListeners();
  }

  Iterable<CanvasNode> get nodes => _nodesByQuadId.values;

  List<(int quadId, CanvasNode node)> get orderedNodes {
    final entries = _nodesByQuadId.entries
        .map<(int, CanvasNode)>((e) => (e.key, e.value))
        .toList(growable: false);
    entries.sort((a, b) {
      final z = a.$2.zIndex.compareTo(b.$2.zIndex);
      if (z != 0) return z;
      return a.$1.compareTo(b.$1);
    });
    return entries;
  }

  CanvasNode? lookupNode(int quadId) => _nodesByQuadId[quadId];

  void _onCameraChanged() => notifyListeners();

  void clearSelection() {
    if (_selectedQuadIds.isEmpty && _primaryQuadId == null) return;
    _selectedQuadIds.clear();
    _primaryQuadId = null;
    notifyListeners();
  }

  void setSelection(Set<int> ids, {int? primary}) {
    _selectedQuadIds
      ..clear()
      ..addAll(ids);
    _primaryQuadId = primary ?? (ids.isEmpty ? null : _pickPrimaryFrom(ids));
    notifyListeners();
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
    notifyListeners();
  }

  void selectSingle(int quadId) {
    if (!_nodesByQuadId.containsKey(quadId)) return;
    _selectedQuadIds
      ..clear()
      ..add(quadId);
    _primaryQuadId = quadId;
    notifyListeners();
  }

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
    _marqueeAnchorWorld = null;
    notifyListeners();
  }

  int _pickPrimaryFrom(Set<int> ids) {
    var bestId = ids.first;
    var bestZ = _nodesByQuadId[bestId]?.zIndex ?? 0;
    for (final id in ids) {
      final z = _nodesByQuadId[id]?.zIndex ?? 0;
      if (z > bestZ || (z == bestZ && id > bestId)) {
        bestZ = z;
        bestId = id;
      }
    }
    return bestId;
  }

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
      return b.compareTo(a);
    });
    return candidates.first;
  }

  int addNode(CanvasNode node) {
    final id = quadTree.insert(node.bounds);
    _nodesByQuadId[id] = node;
    notifyListeners();
    return id;
  }

  void removeNode(int quadId) {
    if (!_nodesByQuadId.containsKey(quadId)) return;
    quadTree.remove(quadId);
    _nodesByQuadId.remove(quadId);
    _groups.removeWhere((_, members) {
      members.remove(quadId);
      return members.isEmpty;
    });
    _quadIdToGroup.remove(quadId);
    if (_hoveredQuadId == quadId) {
      _hoveredQuadId = null;
    }
    _selectedQuadIds.remove(quadId);
    if (_primaryQuadId == quadId) {
      _primaryQuadId = _selectedQuadIds.isEmpty
          ? null
          : _pickPrimaryFrom(_selectedQuadIds);
    }
    notifyListeners();
  }

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

  void relayoutNodes(Iterable<int> quadIds) {
    var any = false;
    for (final id in quadIds) {
      final node = _nodesByQuadId[id];
      if (node == null) continue;
      final r = node.bounds;
      quadTree.move(
        id,
        r.left,
        r.top,
        width: r.width,
        height: r.height,
      );
      any = true;
    }
    if (any) notifyListeners();
  }

  List<CanvasNode> queryVisible({double inflate = 32}) {
    final rect = camera.bound.inflate(inflate);
    final ids = quadTree.queryIds(rect);
    final pairs = <(int, CanvasNode)>[];
    for (final id in ids) {
      final n = _nodesByQuadId[id];
      if (n != null) pairs.add((id, n));
    }
    pairs.sort((a, b) {
      final c = a.$2.zIndex.compareTo(b.$2.zIndex);
      if (c != 0) return c;
      return a.$1.compareTo(b.$1);
    });
    return pairs.map((p) => p.$2).toList();
  }

  void setHoveredQuadId(int? id) {
    if (_hoveredQuadId == id) return;
    _hoveredQuadId = id;
    notifyListeners();
  }

  void clearHover() => setHoveredQuadId(null);

  @override
  void dispose() {
    text.dispose();
    _camera.removeListener(_onCameraChanged);
    if (_ownsCamera) {
      _camera.dispose();
    }
    super.dispose();
  }
}
