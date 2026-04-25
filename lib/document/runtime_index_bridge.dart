import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_document_state.dart';
import 'node_codec.dart';
import 'node_entity.dart';

class RuntimeIndexBridge {
  RuntimeIndexBridge({
    required this.controller,
    required this.documentState,
    required this.nodeCodec,
  });

  final InfiniteCanvasController controller;
  final CanvasDocumentState documentState;
  final NodeCodec nodeCodec;

  final Map<NodeId, int> _quadIdByNodeId = <NodeId, int>{};
  final Map<int, NodeId> _nodeIdByQuadId = <int, NodeId>{};

  Map<NodeId, int> get quadIdByNodeId =>
      Map<NodeId, int>.unmodifiable(_quadIdByNodeId);
  Map<int, NodeId> get nodeIdByQuadId =>
      Map<int, NodeId>.unmodifiable(_nodeIdByQuadId);

  int? quadIdForNodeId(NodeId nodeId) => _quadIdByNodeId[nodeId];

  NodeId? nodeIdForQuadId(int quadId) => _nodeIdByQuadId[quadId];

  void rebuildFromDocument() {
    final existing = controller.orderedNodes.map((entry) => entry.$1).toList();
    for (final quadId in existing) {
      controller.removeNode(quadId);
    }
    _quadIdByNodeId.clear();
    _nodeIdByQuadId.clear();

    final ordered = <NodeEntity>[];
    final root = documentState.rootOrder;
    for (final nodeId in root) {
      final entity = documentState.nodeById(nodeId);
      if (entity != null) {
        ordered.add(entity);
      }
    }
    for (final entity in documentState.nodesById.values) {
      if (root.contains(entity.id)) continue;
      ordered.add(entity);
    }

    for (final entity in ordered) {
      final node = nodeCodec.nodeFromEntity(entity);
      final quadId = controller.addNode(node);
      _quadIdByNodeId[entity.id] = quadId;
      _nodeIdByQuadId[quadId] = entity.id;
    }
  }

  void applyUpsert(NodeId nodeId) {
    final entity = documentState.nodeById(nodeId);
    if (entity == null) {
      applyDelete(nodeId);
      return;
    }
    final existingQuadId = _quadIdByNodeId[nodeId];
    final runtimeNode = nodeCodec.nodeFromEntity(entity);
    if (existingQuadId == null) {
      final newQuadId = controller.addNode(runtimeNode);
      _quadIdByNodeId[nodeId] = newQuadId;
      _nodeIdByQuadId[newQuadId] = nodeId;
      return;
    }
    controller.removeNode(existingQuadId);
    final replacementQuadId = controller.addNode(runtimeNode);
    _quadIdByNodeId[nodeId] = replacementQuadId;
    _nodeIdByQuadId.remove(existingQuadId);
    _nodeIdByQuadId[replacementQuadId] = nodeId;
    if (controller.primaryQuadId == existingQuadId) {
      controller.selectSingle(replacementQuadId);
    }
  }

  void applyDelete(NodeId nodeId) {
    final quadId = _quadIdByNodeId.remove(nodeId);
    if (quadId == null) return;
    _nodeIdByQuadId.remove(quadId);
    controller.removeNode(quadId);
  }

  NodeId promoteRuntimeNodeAsEntity(
    int quadId, {
    NodeId? nodeId,
    NodeId? parentId,
    NodeContainmentData? containment,
  }) {
    final node = controller.lookupNode(quadId);
    if (node == null) {
      throw StateError('Runtime node not found for quadId=$quadId');
    }
    final id = nodeId ?? nodeCodec.newNodeId();
    final entity = nodeCodec.entityFromNode(
      node,
      nodeId: id,
      parentId: parentId,
      containment: containment,
    );
    documentState.upsertNode(entity);
    _quadIdByNodeId[id] = quadId;
    _nodeIdByQuadId[quadId] = id;
    return id;
  }

  List<NodeId> staleNodeIdsFromController() {
    final stale = <NodeId>[];
    for (final entry in _quadIdByNodeId.entries) {
      if (controller.lookupNode(entry.value) == null) {
        stale.add(entry.key);
      }
    }
    return stale;
  }
}
