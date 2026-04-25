import 'canvas_document_state.dart';
import 'document_ops.dart';
import 'runtime_index_bridge.dart';

class DocumentReducer {
  DocumentReducer({required this.documentState, required this.runtimeBridge});

  final CanvasDocumentState documentState;
  final RuntimeIndexBridge runtimeBridge;

  void dispatch(DocumentOp op) {
    switch (op) {
      case NodeCreated():
        documentState.upsertNode(op.node, notify: false);
        runtimeBridge.applyUpsert(op.node.id);
      case NodeDeleted():
        documentState.removeNode(op.nodeId, notify: false);
        runtimeBridge.applyDelete(op.nodeId);
      case NodePatched():
        final current = documentState.nodeById(op.nodeId);
        if (current == null) return;
        documentState.upsertNode(
          current.copyWith(
            label: op.label,
            visible: op.visible,
            locked: op.locked,
            zIndex: op.zIndex,
          ),
          notify: false,
        );
        runtimeBridge.applyUpsert(op.nodeId);
      case GeometryPatched():
        final current = documentState.nodeById(op.nodeId);
        if (current == null) return;
        documentState.upsertNode(
          current.copyWith(geometry: Map<String, dynamic>.from(op.geometry)),
          notify: false,
        );
        runtimeBridge.applyUpsert(op.nodeId);
      case StylePatched():
        final current = documentState.nodeById(op.nodeId);
        if (current == null) return;
        documentState.upsertNode(
          current.copyWith(style: Map<String, dynamic>.from(op.style)),
          notify: false,
        );
        runtimeBridge.applyUpsert(op.nodeId);
      case NodeReparented():
        final current = documentState.nodeById(op.nodeId);
        if (current == null) return;
        documentState.upsertNode(
          current.copyWith(
            parentId: op.parentId,
            clearParentId: op.parentId == null,
            containment: op.containment,
            clearContainment: op.containment == null,
          ),
          notify: false,
        );
      case OrderChanged():
        if (op.parentId == null) {
          documentState.reorderRoot(op.orderedNodeIds, notify: false);
        }
    }
    documentState.emitChange();
  }
}
