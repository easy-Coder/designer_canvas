import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';

Set<int> propagateFrameChildMotion({
  required InfiniteCanvasController controller,
  required CanvasDocumentState documentState,
  required RuntimeIndexBridge runtimeBridge,
  required Map<String, ui.Offset> framePivotSnapshotByNodeId,
}) {
  final moved = <int>{};
  final orderedFrames = <(int, FrameNode)>[];
  for (final (quadId, node) in controller.orderedNodes) {
    if (node is FrameNode) {
      orderedFrames.add((quadId, node));
    }
  }
  for (final (frameQuadId, frameNode) in orderedFrames) {
    final frameNodeId = runtimeBridge.nodeIdForQuadId(frameQuadId);
    if (frameNodeId == null) continue;
    final currentPivot = frameNode.transformPivot;
    final previousPivot = framePivotSnapshotByNodeId[frameNodeId];
    framePivotSnapshotByNodeId[frameNodeId] = currentPivot;
    if (previousPivot == null) continue;
    final children = documentState.childrenOf(frameNodeId);
    for (final childNodeId in children) {
      final childQuadId = runtimeBridge.quadIdForNodeId(childNodeId);
      if (childQuadId == null) continue;
      final childNode = controller.lookupNode(childQuadId);
      if (childNode == null) continue;
      final localPivot = documentState
          .nodeById(childNodeId)
          ?.containment
          ?.localPivot;
      if (localPivot == null) continue;
      final expectedChildPivot = ui.Offset(
        currentPivot.dx + localPivot.dx,
        currentPivot.dy + localPivot.dy,
      );
      final delta = expectedChildPivot - childNode.transformPivot;
      if (delta.distanceSquared < 1e-12) continue;
      childNode.translateWorld(delta);
      moved.add(childQuadId);
    }
  }
  if (moved.isNotEmpty) {
    controller.relayoutNodes(moved);
  }
  return moved;
}
