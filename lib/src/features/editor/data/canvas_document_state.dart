import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';

/// Selection state held alongside the node tree. Identifiers are document
/// ([NodeId]) values, not runtime quad ids.
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
      primaryNodeId:
          clearPrimary ? null : (primaryNodeId ?? this.primaryNodeId),
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
    );
  }
}

/// Single source of truth for the canvas document.
///
/// Holds the immutable [NodeEntity] records plus the top-level `rootOrder`
/// (z-order of nodes that are not nested inside a frame) and the current
/// [DocumentSelectionState]. Mutations go through dedicated, typed methods
/// (`addNode`, `setPos`, `patchMetadata`, `addChild`, ...) that fire
/// [notifyListeners] exactly once per call.
///
/// All previous CRDT-style metadata (actorId/seq/lamport, lastOpSeqByActor)
/// has been removed; this document is intentionally local-only.
class CanvasDocumentState extends ChangeNotifier {
  CanvasDocumentState({
    required this.docId,
    this.schemaVersion = 1,
    this.createdAtEpochMs,
    this.updatedAtEpochMs,
    Map<NodeId, NodeEntity>? nodesById,
    List<NodeId>? rootOrder,
    DocumentSelectionState? selectionState,
  })  : _nodesById = nodesById ?? <NodeId, NodeEntity>{},
        _rootOrder = rootOrder ?? <NodeId>[],
        _selectionState = selectionState ?? const DocumentSelectionState();

  final String docId;
  final int schemaVersion;
  final int? createdAtEpochMs;
  int? updatedAtEpochMs;

  final Map<NodeId, NodeEntity> _nodesById;
  final List<NodeId> _rootOrder;
  DocumentSelectionState _selectionState;

  // ─── Read API ───────────────────────────────────────────────────────────

  UnmodifiableMapView<NodeId, NodeEntity> get nodesById =>
      UnmodifiableMapView(_nodesById);

  UnmodifiableListView<NodeId> get rootOrder =>
      UnmodifiableListView(_rootOrder);

  DocumentSelectionState get selectionState => _selectionState;

  NodeEntity? nodeById(NodeId id) => _nodesById[id];

  bool containsNode(NodeId id) => _nodesById.containsKey(id);

  /// Returns the parent frame id of [id] by scanning frame children lists.
  ///
  /// Children are stored on [FrameNodeEntity], so this is a linear search by
  /// design — typical canvases stay small enough that this is fine; if it
  /// ever becomes a hotspot, a derived index can be added without changing
  /// the on-disk representation.
  NodeId? parentOf(NodeId id) {
    for (final entity in _nodesById.values) {
      if (entity is FrameNodeEntity && entity.children.contains(id)) {
        return entity.id;
      }
    }
    return null;
  }

  /// Returns the children for [id]; non-frame nodes always return an empty
  /// list.
  List<NodeId> childrenOf(NodeId id) {
    final entity = _nodesById[id];
    if (entity is FrameNodeEntity) {
      return List<NodeId>.unmodifiable(entity.children);
    }
    return const <NodeId>[];
  }

  /// True if [probeId] is anywhere in the descendant subtree of
  /// [ancestorId] (frame children, recursive).
  bool isDescendantOf(NodeId ancestorId, NodeId probeId) {
    final ancestor = _nodesById[ancestorId];
    if (ancestor is! FrameNodeEntity) return false;
    if (ancestor.children.contains(probeId)) return true;
    for (final child in ancestor.children) {
      if (isDescendantOf(child, probeId)) return true;
    }
    return false;
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  /// Inserts [node] into the document. When [parentFrameId] is provided the
  /// node is appended to that frame's children (the frame must exist).
  /// Otherwise it is appended to [rootOrder].
  void addNode(
    NodeEntity node, {
    NodeId? parentFrameId,
    bool notify = true,
  }) {
    _nodesById[node.id] = node;
    if (parentFrameId != null) {
      final parent = _nodesById[parentFrameId];
      if (parent is! FrameNodeEntity) {
        throw StateError(
          'addNode: parentFrameId="$parentFrameId" is not a frame',
        );
      }
      if (!parent.children.contains(node.id)) {
        _nodesById[parentFrameId] = parent.copyWith(
          children: [...parent.children, node.id],
        );
      }
      _rootOrder.remove(node.id);
    } else if (!_rootOrder.contains(node.id)) {
      _rootOrder.add(node.id);
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Removes [id] (and all of its descendants when it is a frame). Cleans up
  /// the parent frame's `children` list and the selection.
  void removeNode(NodeId id, {bool notify = true}) {
    if (!_nodesById.containsKey(id)) return;
    final removedIds = <NodeId>{};
    _collectSubtree(id, removedIds);
    final parentId = parentOf(id);
    if (parentId != null) {
      final parent = _nodesById[parentId];
      if (parent is FrameNodeEntity) {
        _nodesById[parentId] = parent.copyWith(
          children:
              parent.children.where((c) => c != id).toList(growable: false),
        );
      }
    }
    for (final removed in removedIds) {
      _nodesById.remove(removed);
      _rootOrder.remove(removed);
    }
    if (removedIds.isNotEmpty) {
      _selectionState = _selectionState.copyWith(
        clearPrimary: removedIds.contains(_selectionState.primaryNodeId),
        selectedNodeIds: _selectionState.selectedNodeIds
            .where((v) => !removedIds.contains(v))
            .toSet(),
      );
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Sets the top-left position of [id] to ([x], [y]) in world coords. When
  /// the entity is a [FrameNodeEntity] the same delta is applied to every
  /// descendant so children move with the frame.
  void setPos(NodeId id, double x, double y, {bool notify = true}) {
    final current = _nodesById[id];
    if (current == null) return;
    final dx = x - current.pos.x;
    final dy = y - current.pos.y;
    if (dx == 0 && dy == 0) return;
    _translate(id, dx, dy);
    _touch();
    if (notify) notifyListeners();
  }

  /// Applies [dx]/[dy] to [id] and recursively to its descendants when [id]
  /// is a frame. Internal helper that does **not** notify on its own.
  ///
  /// Line/arrow endpoints (stored in `metadata` as world coords) are
  /// translated by the same delta so they stay in sync with `pos`.
  void _translate(NodeId id, double dx, double dy) {
    final entity = _nodesById[id];
    if (entity == null) return;
    final newPos = NodePos(entity.pos.x + dx, entity.pos.y + dy);
    final newMeta = _translateLineEndpoints(entity, dx, dy);
    switch (entity) {
      case LeafNodeEntity():
        _nodesById[id] = entity.copyWith(
          pos: newPos,
          metadata: newMeta ?? entity.metadata,
        );
      case FrameNodeEntity():
        _nodesById[id] = entity.copyWith(
          pos: newPos,
          metadata: newMeta ?? entity.metadata,
        );
        for (final childId in entity.children) {
          _translate(childId, dx, dy);
        }
    }
  }

  /// Returns a new metadata map with line/arrow endpoints translated, or
  /// null when the entity has no endpoint fields to update.
  Map<String, dynamic>? _translateLineEndpoints(
    NodeEntity entity,
    double dx,
    double dy,
  ) {
    if (entity.type != NodeEntityType.line &&
        entity.type != NodeEntityType.arrow) {
      return null;
    }
    final m = Map<String, dynamic>.from(entity.metadata);
    void shift(String key, double delta) {
      final v = (m[key] as num?)?.toDouble();
      if (v != null) m[key] = v + delta;
    }

    shift('startX', dx);
    shift('startY', dy);
    shift('endX', dx);
    shift('endY', dy);
    return m;
  }

  /// Updates the human-readable name on [id].
  void setName(NodeId id, String name, {bool notify = true}) {
    final current = _nodesById[id];
    if (current == null) return;
    final cleaned = name.trim().isEmpty ? 'Node' : name;
    if (current.name == cleaned) return;
    switch (current) {
      case LeafNodeEntity():
        _nodesById[id] = current.copyWith(name: cleaned);
      case FrameNodeEntity():
        _nodesById[id] = current.copyWith(name: cleaned);
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Shallow-merges [patch] into the entity's `metadata` map. Existing keys
  /// are overwritten; keys not present in [patch] are preserved.
  void patchMetadata(
    NodeId id,
    Map<String, dynamic> patch, {
    bool notify = true,
  }) {
    final current = _nodesById[id];
    if (current == null) return;
    if (patch.isEmpty) return;
    final next = Map<String, dynamic>.from(current.metadata)..addAll(patch);
    switch (current) {
      case LeafNodeEntity():
        _nodesById[id] = current.copyWith(metadata: next);
      case FrameNodeEntity():
        _nodesById[id] = current.copyWith(metadata: next);
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Replaces an existing entity wholesale. The id must already exist in
  /// the document; tree structure ([rootOrder] and parent frame children)
  /// is preserved. Used by gesture commits that have already computed the
  /// final pos+metadata snapshot in one place and don't want the cascading
  /// behavior of [setPos].
  void replaceEntity(NodeEntity entity, {bool notify = true}) {
    if (!_nodesById.containsKey(entity.id)) return;
    if (identical(_nodesById[entity.id], entity)) return;
    _nodesById[entity.id] = entity;
    _touch();
    if (notify) notifyListeners();
  }

  /// Replaces the entity's metadata wholesale.
  void setMetadata(
    NodeId id,
    Map<String, dynamic> metadata, {
    bool notify = true,
  }) {
    final current = _nodesById[id];
    if (current == null) return;
    final next = Map<String, dynamic>.from(metadata);
    switch (current) {
      case LeafNodeEntity():
        _nodesById[id] = current.copyWith(metadata: next);
      case FrameNodeEntity():
        _nodesById[id] = current.copyWith(metadata: next);
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Appends [childId] to [frameId]'s `children`. Removes [childId] from any
  /// previous parent and from [rootOrder]. Throws when [frameId] is not a
  /// frame, when the move would create a cycle, or when [childId] equals
  /// [frameId].
  void addChild(NodeId frameId, NodeId childId, {bool notify = true}) {
    if (frameId == childId) {
      throw StateError('addChild: a node cannot be its own parent');
    }
    final frame = _nodesById[frameId];
    if (frame is! FrameNodeEntity) {
      throw StateError('addChild: "$frameId" is not a frame');
    }
    if (!_nodesById.containsKey(childId)) {
      throw StateError('addChild: child "$childId" not in document');
    }
    if (isDescendantOf(childId, frameId)) {
      throw StateError('addChild: would create a cycle');
    }
    final previousParent = parentOf(childId);
    if (previousParent == frameId) return;
    if (previousParent != null) {
      final prev = _nodesById[previousParent];
      if (prev is FrameNodeEntity) {
        _nodesById[previousParent] = prev.copyWith(
          children:
              prev.children.where((c) => c != childId).toList(growable: false),
        );
      }
    }
    _rootOrder.remove(childId);
    if (!frame.children.contains(childId)) {
      _nodesById[frameId] = frame.copyWith(
        children: [...frame.children, childId],
      );
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Detaches [childId] from [frameId] and reinserts it at the end of
  /// [rootOrder].
  void removeChild(NodeId frameId, NodeId childId, {bool notify = true}) {
    final frame = _nodesById[frameId];
    if (frame is! FrameNodeEntity) {
      throw StateError('removeChild: "$frameId" is not a frame');
    }
    if (!frame.children.contains(childId)) return;
    _nodesById[frameId] = frame.copyWith(
      children:
          frame.children.where((c) => c != childId).toList(growable: false),
    );
    if (!_rootOrder.contains(childId) && _nodesById.containsKey(childId)) {
      _rootOrder.add(childId);
    }
    _touch();
    if (notify) notifyListeners();
  }

  /// Replaces [frameId]'s children with [orderedNodeIds] (which must be a
  /// permutation of the existing children).
  void reorderChildren(
    NodeId frameId,
    List<NodeId> orderedNodeIds, {
    bool notify = true,
  }) {
    final frame = _nodesById[frameId];
    if (frame is! FrameNodeEntity) {
      throw StateError('reorderChildren: "$frameId" is not a frame');
    }
    final filtered =
        orderedNodeIds.where(frame.children.contains).toList(growable: false);
    _nodesById[frameId] = frame.copyWith(children: filtered);
    _touch();
    if (notify) notifyListeners();
  }

  /// Replaces the root z-order list with the subset of [orderedNodeIds] that
  /// resolve to known nodes.
  void reorderRoot(List<NodeId> orderedNodeIds, {bool notify = true}) {
    _rootOrder
      ..clear()
      ..addAll(orderedNodeIds.where(_nodesById.containsKey));
    _touch();
    if (notify) notifyListeners();
  }

  void setSelection(DocumentSelectionState value, {bool notify = true}) {
    _selectionState = value;
    if (notify) notifyListeners();
  }

  /// Forces a notification without mutating any state. Useful when batching
  /// silent mutations and emitting a single change at the end.
  void emitChange() {
    notifyListeners();
  }

  // ─── Persistence ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'docId': docId,
      'createdAtEpochMs': createdAtEpochMs,
      'updatedAtEpochMs': updatedAtEpochMs,
      'nodes': _nodesById.map((key, value) => MapEntry(key, value.toJson())),
      'rootOrder': _rootOrder,
      'selection': _selectionState.toJson(),
    };
  }

  factory CanvasDocumentState.fromJson(Map<String, dynamic> json) {
    final rawNodes = (json['nodes'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final nodes = <NodeId, NodeEntity>{};
    for (final entry in rawNodes.entries) {
      final data = (entry.value as Map?)?.cast<String, dynamic>();
      if (data == null) continue;
      final entity = NodeEntity.fromJson(data);
      final key = entity.id.isEmpty ? entry.key : entity.id;
      nodes[key] = entity.id == key ? entity : entity._withId(key);
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
    );
  }

  /// Validates document invariants: no node appears in more than one
  /// frame's children, no cycles, and every frame.children entry exists.
  /// (The "only frames have children" rule is enforced by the type system.)
  List<String> validateInvariants() {
    final issues = <String>[];
    final seenParents = <NodeId, NodeId>{};
    for (final entity in _nodesById.values) {
      if (entity is! FrameNodeEntity) continue;
      for (final childId in entity.children) {
        if (!_nodesById.containsKey(childId)) {
          issues.add('child-missing:${entity.id}:$childId');
          continue;
        }
        final previous = seenParents[childId];
        if (previous != null && previous != entity.id) {
          issues.add('multiple-parent:$childId:$previous:${entity.id}');
        }
        seenParents[childId] = entity.id;
        if (childId == entity.id) {
          issues.add('self-parent:${entity.id}');
        }
        if (isDescendantOf(childId, entity.id)) {
          issues.add('cycle:${entity.id}:$childId');
        }
      }
    }
    return issues;
  }

  void _collectSubtree(NodeId id, Set<NodeId> sink) {
    if (!sink.add(id)) return;
    final entity = _nodesById[id];
    if (entity is FrameNodeEntity) {
      for (final childId in entity.children) {
        _collectSubtree(childId, sink);
      }
    }
  }

  void _touch() {
    updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
  }
}

extension _NodeEntityIdRebind on NodeEntity {
  /// Internal helper used during JSON decoding when the on-disk key for an
  /// entity differs from the encoded `id`. Rebuilds the entity with the
  /// authoritative id, preserving subtype.
  NodeEntity _withId(NodeId id) {
    switch (this) {
      case LeafNodeEntity(
          name: final name,
          pos: final pos,
          metadata: final metadata,
          type: final type
        ):
        return LeafNodeEntity(
          id: id,
          name: name,
          pos: pos,
          metadata: metadata,
          type: type,
        );
      case FrameNodeEntity(
          name: final name,
          pos: final pos,
          metadata: final metadata,
          children: final children
        ):
        return FrameNodeEntity(
          id: id,
          name: name,
          pos: pos,
          metadata: metadata,
          children: children,
        );
    }
  }
}
