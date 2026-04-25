import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'node_entity.dart';

class DocumentSelectionState {
  const DocumentSelectionState({
    this.primaryNodeId,
    Set<NodeId>? selectedNodeIds,
  }) : selectedNodeIds = selectedNodeIds ?? const <NodeId>{};

  final NodeId? primaryNodeId;
  final Set<NodeId> selectedNodeIds;

  Map<String, dynamic> toJson() {
    return {
      'primaryNodeId': primaryNodeId,
      'selectedNodeIds': selectedNodeIds.toList(growable: false),
    };
  }

  factory DocumentSelectionState.fromJson(Map<String, dynamic> json) {
    return DocumentSelectionState(
      primaryNodeId: json['primaryNodeId'] as String?,
      selectedNodeIds: (json['selectedNodeIds'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
    );
  }

  DocumentSelectionState copyWith({
    NodeId? primaryNodeId,
    bool clearPrimary = false,
    Set<NodeId>? selectedNodeIds,
  }) {
    return DocumentSelectionState(
      primaryNodeId: clearPrimary
          ? null
          : (primaryNodeId ?? this.primaryNodeId),
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
    );
  }
}

class CanvasDocumentState extends ChangeNotifier {
  CanvasDocumentState({
    required this.docId,
    this.schemaVersion = 1,
    this.createdAtEpochMs,
    this.updatedAtEpochMs,
    Map<NodeId, NodeEntity>? nodesById,
    List<NodeId>? rootOrder,
    DocumentSelectionState? selectionState,
    Map<NodeId, int>? lastOpSeqByActor,
  }) : _nodesById = nodesById ?? <NodeId, NodeEntity>{},
       _rootOrder = rootOrder ?? <NodeId>[],
       _selectionState = selectionState ?? const DocumentSelectionState(),
       _lastOpSeqByActor = lastOpSeqByActor ?? <NodeId, int>{} {
    _rebuildRelationshipIndexes();
  }

  final String docId;
  final int schemaVersion;
  final int? createdAtEpochMs;
  int? updatedAtEpochMs;
  final Map<NodeId, NodeEntity> _nodesById;
  final List<NodeId> _rootOrder;
  final Map<NodeId, int> _lastOpSeqByActor;

  late DocumentSelectionState _selectionState;
  final Map<NodeId, NodeId> _parentByChild = <NodeId, NodeId>{};
  final Map<NodeId, List<NodeId>> _childrenByParent = <NodeId, List<NodeId>>{};

  UnmodifiableMapView<NodeId, NodeEntity> get nodesById =>
      UnmodifiableMapView(_nodesById);

  UnmodifiableListView<NodeId> get rootOrder =>
      UnmodifiableListView(_rootOrder);

  DocumentSelectionState get selectionState => _selectionState;

  UnmodifiableMapView<NodeId, NodeId> get parentByChild =>
      UnmodifiableMapView(_parentByChild);

  Map<NodeId, List<NodeId>> get childrenByParent {
    final copy = <NodeId, List<NodeId>>{};
    for (final entry in _childrenByParent.entries) {
      copy[entry.key] = List<NodeId>.unmodifiable(entry.value);
    }
    return copy;
  }

  UnmodifiableMapView<NodeId, int> get lastOpSeqByActor =>
      UnmodifiableMapView(_lastOpSeqByActor);

  NodeEntity? nodeById(NodeId id) => _nodesById[id];

  NodeId? parentOf(NodeId id) => _parentByChild[id];

  List<NodeId> childrenOf(NodeId id) {
    return List<NodeId>.unmodifiable(_childrenByParent[id] ?? const <NodeId>[]);
  }

  bool containsNode(NodeId id) => _nodesById.containsKey(id);

  bool isDescendantOf(NodeId ancestorId, NodeId probeId) {
    final children = _childrenByParent[ancestorId];
    if (children == null || children.isEmpty) return false;
    if (children.contains(probeId)) return true;
    for (final child in children) {
      if (isDescendantOf(child, probeId)) return true;
    }
    return false;
  }

  void upsertNode(NodeEntity node, {bool notify = true}) {
    _nodesById[node.id] = node;
    if (!_rootOrder.contains(node.id) && node.parentId == null) {
      _rootOrder.add(node.id);
    }
    if (node.parentId != null) {
      _rootOrder.remove(node.id);
    }
    _rebuildRelationshipIndexes();
    _touch();
    if (notify) {
      notifyListeners();
    }
  }

  void removeNode(NodeId id, {bool notify = true}) {
    final removed = _nodesById.remove(id);
    if (removed == null) return;
    _rootOrder.remove(id);
    _selectionState = _selectionState.copyWith(
      selectedNodeIds: _selectionState.selectedNodeIds
          .where((v) => v != id)
          .toSet(),
      clearPrimary: _selectionState.primaryNodeId == id,
    );
    final children = List<NodeId>.from(
      _childrenByParent[id] ?? const <NodeId>[],
    );
    for (final childId in children) {
      final child = _nodesById[childId];
      if (child == null) continue;
      _nodesById[childId] = child.copyWith(
        clearParentId: true,
        clearContainment: true,
      );
      if (!_rootOrder.contains(childId)) {
        _rootOrder.add(childId);
      }
    }
    _rebuildRelationshipIndexes();
    _touch();
    if (notify) {
      notifyListeners();
    }
  }

  void setSelection(DocumentSelectionState value, {bool notify = true}) {
    _selectionState = value;
    if (notify) {
      notifyListeners();
    }
  }

  void reorderRoot(List<NodeId> orderedNodeIds, {bool notify = true}) {
    _rootOrder
      ..clear()
      ..addAll(orderedNodeIds.where(_nodesById.containsKey));
    _touch();
    if (notify) {
      notifyListeners();
    }
  }

  void setLastActorSequence(NodeId actorId, int seq, {bool notify = false}) {
    _lastOpSeqByActor[actorId] = seq;
    if (notify) {
      notifyListeners();
    }
  }

  void emitChange() {
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'docId': docId,
      'createdAtEpochMs': createdAtEpochMs,
      'updatedAtEpochMs': updatedAtEpochMs,
      'nodes': _nodesById.map((key, value) => MapEntry(key, value.toJson())),
      'rootOrder': _rootOrder,
      'selection': _selectionState.toJson(),
      'lastOpSeqByActor': _lastOpSeqByActor,
    };
  }

  factory CanvasDocumentState.fromJson(Map<String, dynamic> json) {
    final rawNodes =
        (json['nodes'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final nodes = <NodeId, NodeEntity>{};
    for (final entry in rawNodes.entries) {
      final data = (entry.value as Map?)?.cast<String, dynamic>();
      if (data == null) continue;
      final entity = NodeEntity.fromJson(data);
      final key = entity.id.isEmpty ? entry.key : entity.id;
      nodes[key] = entity.copyWith(id: key);
    }
    return CanvasDocumentState(
      docId: (json['docId'] as String?) ?? 'doc',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt(),
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt(),
      nodesById: nodes,
      rootOrder: (json['rootOrder'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      selectionState: DocumentSelectionState.fromJson(
        (json['selection'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      lastOpSeqByActor:
          (json['lastOpSeqByActor'] as Map?)?.cast<String, dynamic>().map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          <NodeId, int>{},
    );
  }

  List<String> validateInvariants() {
    final issues = <String>[];
    final seenParents = <NodeId, NodeId>{};
    for (final node in _nodesById.values) {
      final parentId = node.parentId;
      if (parentId == null) continue;
      if (!_nodesById.containsKey(parentId)) {
        issues.add('parent-missing:${node.id}:$parentId');
      }
      final previous = seenParents[node.id];
      if (previous != null && previous != parentId) {
        issues.add('multiple-parent:${node.id}:$previous:$parentId');
      }
      seenParents[node.id] = parentId;
      if (node.id == parentId) {
        issues.add('self-parent:${node.id}');
      }
      if (isDescendantOf(node.id, parentId)) {
        issues.add('cycle:${node.id}:$parentId');
      }
      if (node.containment == null) {
        issues.add('missing-containment:${node.id}:$parentId');
      }
    }
    return issues;
  }

  void _touch() {
    updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _rebuildRelationshipIndexes() {
    _parentByChild.clear();
    _childrenByParent.clear();
    for (final entry in _nodesById.entries) {
      final childId = entry.key;
      final parentId = entry.value.parentId;
      if (parentId == null) continue;
      _parentByChild[childId] = parentId;
      (_childrenByParent[parentId] ??= <NodeId>[]).add(childId);
    }
    for (final entry in _childrenByParent.entries) {
      entry.value.sort();
    }
  }
}
