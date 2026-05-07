import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';

import 'canvas_document_state.dart';
import 'node_codec.dart';

/// One-way projection from [CanvasDocumentState] (single source of truth)
/// onto an [InfiniteCanvasController]'s runtime quadtree.
///
/// This is the only place where document changes become runtime
/// [CanvasNode] mutations. There is no reverse path — gestures and inspector
/// edits dispatch directly into [CanvasDocumentState], which then notifies
/// this renderer to rebuild the affected runtime nodes.
///
/// Maintains a `nodeId ↔ quadId` index because the underlying runtime uses
/// integer quad ids for hit testing and selection. Nothing about that index
/// is "syncing"; it is purely an addressing translation between the two
/// layers.
class DocumentCanvasRenderer {
  DocumentCanvasRenderer({
    required this.controller,
    required this.documentState,
    required this.nodeCodec,
  }) {
    documentState.addListener(_onDocumentChanged);
  }

  final InfiniteCanvasController controller;
  final CanvasDocumentState documentState;
  final NodeCodec nodeCodec;

  final Map<NodeId, int> _quadIdByNodeId = <NodeId, int>{};
  final Map<int, NodeId> _nodeIdByQuadId = <int, NodeId>{};

  /// Caches the last rendered entity instance per id so we can skip
  /// rebuilding nodes whose backing entity didn't change. Document
  /// mutations always produce a new instance (immutable copyWith), so an
  /// identity check is enough.
  final Map<NodeId, NodeEntity> _lastRendered = <NodeId, NodeEntity>{};

  Map<NodeId, int> get quadIdByNodeId =>
      Map<NodeId, int>.unmodifiable(_quadIdByNodeId);
  Map<int, NodeId> get nodeIdByQuadId =>
      Map<int, NodeId>.unmodifiable(_nodeIdByQuadId);

  int? quadIdForNodeId(NodeId nodeId) => _quadIdByNodeId[nodeId];

  NodeId? nodeIdForQuadId(int quadId) => _nodeIdByQuadId[quadId];

  /// Fully rebuilds the runtime view from the current document. Call once
  /// after construction and any time the document is replaced wholesale.
  void rebuildFromDocument() {
    final existing = controller.orderedNodes.map((entry) => entry.$1).toList();
    for (final quadId in existing) {
      controller.removeNode(quadId);
    }
    _quadIdByNodeId.clear();
    _nodeIdByQuadId.clear();
    _lastRendered.clear();

    for (final entity in _orderedEntitiesForRender()) {
      final quadId = controller.addNode(nodeCodec.nodeFromEntity(entity));
      _quadIdByNodeId[entity.id] = quadId;
      _nodeIdByQuadId[quadId] = entity.id;
      _lastRendered[entity.id] = entity;
    }
  }

  /// Rebuilds a single node by replacing its runtime instance.
  void replaceNode(NodeId nodeId) {
    final entity = documentState.nodeById(nodeId);
    if (entity == null) {
      _detach(nodeId);
      return;
    }
    final existingQuadId = _quadIdByNodeId[nodeId];
    final runtimeNode = nodeCodec.nodeFromEntity(entity);
    if (existingQuadId == null) {
      final newQuadId = controller.addNode(runtimeNode);
      _quadIdByNodeId[nodeId] = newQuadId;
      _nodeIdByQuadId[newQuadId] = nodeId;
      _lastRendered[nodeId] = entity;
      return;
    }
    final wasPrimary = controller.primaryQuadId == existingQuadId;
    final wasSelected =
        controller.selectedQuadIds.contains(existingQuadId);
    controller.removeNode(existingQuadId);
    final replacementQuadId = controller.addNode(runtimeNode);
    _quadIdByNodeId[nodeId] = replacementQuadId;
    _nodeIdByQuadId.remove(existingQuadId);
    _nodeIdByQuadId[replacementQuadId] = nodeId;
    _lastRendered[nodeId] = entity;
    if (wasPrimary) {
      controller.selectSingle(replacementQuadId);
    } else if (wasSelected) {
      final next = controller.selectedQuadIds.toSet()..add(replacementQuadId);
      controller.setSelection(next, primary: controller.primaryQuadId);
    }
  }

  void _detach(NodeId nodeId) {
    final quadId = _quadIdByNodeId.remove(nodeId);
    if (quadId == null) return;
    _nodeIdByQuadId.remove(quadId);
    _lastRendered.remove(nodeId);
    controller.removeNode(quadId);
  }

  /// Diff the current document against the cached runtime view, then add /
  /// replace / remove only the entities whose backing instance changed.
  ///
  /// Document mutations always create a new immutable [NodeEntity] instance,
  /// so identity equality against [_lastRendered] is sufficient to skip
  /// no-op rebuilds.
  void _onDocumentChanged() {
    final desired = documentState.nodesById;
    final stale = _quadIdByNodeId.keys
        .where((id) => !desired.containsKey(id))
        .toList(growable: false);
    for (final id in stale) {
      _detach(id);
    }
    for (final entity in _orderedEntitiesForRender()) {
      final cached = _lastRendered[entity.id];
      if (identical(cached, entity)) continue;
      replaceNode(entity.id);
    }
  }

  /// Iterates entities in z-order (rootOrder first, then nested children of
  /// each frame in the order they appear) so paint order reflects the
  /// document tree.
  Iterable<NodeEntity> _orderedEntitiesForRender() sync* {
    final visited = <NodeId>{};
    Iterable<NodeEntity> walk(NodeId id) sync* {
      if (!visited.add(id)) return;
      final entity = documentState.nodeById(id);
      if (entity == null) return;
      yield entity;
      if (entity is FrameNodeEntity) {
        for (final childId in entity.children) {
          yield* walk(childId);
        }
      }
    }

    for (final id in documentState.rootOrder) {
      yield* walk(id);
    }
    // Catch any nodes that aren't reachable from rootOrder (e.g. orphans).
    for (final id in documentState.nodesById.keys) {
      yield* walk(id);
    }
  }

  /// Permanent listener removal. Call from owning widget's `dispose`.
  void dispose() {
    documentState.removeListener(_onDocumentChanged);
  }
}

/// Shorthand alias preserved for components that imported the old name.
@Deprecated('Use DocumentCanvasRenderer')
typedef RuntimeIndexBridge = DocumentCanvasRenderer;
