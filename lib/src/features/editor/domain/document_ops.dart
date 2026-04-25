import 'node_entity.dart';

sealed class DocumentOp {
  const DocumentOp();
}

class NodeCreated extends DocumentOp {
  const NodeCreated(this.node);
  final NodeEntity node;
}

class NodeDeleted extends DocumentOp {
  const NodeDeleted(this.nodeId);
  final NodeId nodeId;
}

class NodePatched extends DocumentOp {
  const NodePatched({
    required this.nodeId,
    this.label,
    this.visible,
    this.locked,
    this.zIndex,
  });

  final NodeId nodeId;
  final String? label;
  final bool? visible;
  final bool? locked;
  final int? zIndex;
}

class GeometryPatched extends DocumentOp {
  const GeometryPatched({required this.nodeId, required this.geometry});
  final NodeId nodeId;
  final Map<String, dynamic> geometry;
}

class StylePatched extends DocumentOp {
  const StylePatched({required this.nodeId, required this.style});
  final NodeId nodeId;
  final Map<String, dynamic> style;
}

class NodeReparented extends DocumentOp {
  const NodeReparented({required this.nodeId, this.parentId, this.containment});

  final NodeId nodeId;
  final NodeId? parentId;
  final NodeContainmentData? containment;
}

class OrderChanged extends DocumentOp {
  const OrderChanged({this.parentId, required this.orderedNodeIds});
  final NodeId? parentId;
  final List<NodeId> orderedNodeIds;
}
