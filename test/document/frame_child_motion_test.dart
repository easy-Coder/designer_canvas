import 'dart:ui' as ui;

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/node_codec.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_child_motion.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

void main() {
  group('propagateFrameChildMotion', () {
    late InfiniteCanvasController controller;
    late CanvasDocumentState documentState;
    late RuntimeIndexBridge bridge;
    late NodeCodec codec;

    setUp(() {
      controller = InfiniteCanvasController(
        worldBounds: const ui.Rect.fromLTWH(-2000, -2000, 4000, 4000),
      );
      documentState = CanvasDocumentState(docId: 'doc');
      codec = NodeCodec();
      bridge = RuntimeIndexBridge(
        controller: controller,
        documentState: documentState,
        nodeCodec: codec,
      );
    });

    tearDown(() {
      controller.dispose();
      documentState.dispose();
    });

    test('moves frame children by frame delta', () {
      final frameQuadId = controller.addNode(
        FrameNode(
          center: const ui.Offset(100, 100),
          width: 200,
          height: 200,
          style: const FrameNodeStyle(),
        ),
      );
      final childQuadId = controller.addNode(
        RectNode(
          center: const ui.Offset(120, 130),
          width: 50,
          height: 40,
          style: const RectNodeStyle(),
        ),
      );

      final frameId = bridge.promoteRuntimeNodeAsEntity(
        frameQuadId,
        nodeId: 'frame',
      );
      final childId = bridge.promoteRuntimeNodeAsEntity(
        childQuadId,
        nodeId: 'child',
      );
      documentState.upsertNode(
        documentState
            .nodeById(childId)!
            .copyWith(
              parentId: frameId,
              containment: const NodeContainmentData(
                localPivotX: 20,
                localPivotY: 30,
              ),
            ),
      );

      final snapshots = <String, ui.Offset>{};
      propagateFrameChildMotion(
        controller: controller,
        documentState: documentState,
        runtimeBridge: bridge,
        framePivotSnapshotByNodeId: snapshots,
      );

      final frameNode = controller.lookupNode(frameQuadId)!;
      frameNode.translateWorld(const ui.Offset(40, -10));
      controller.updateNode(frameQuadId);

      propagateFrameChildMotion(
        controller: controller,
        documentState: documentState,
        runtimeBridge: bridge,
        framePivotSnapshotByNodeId: snapshots,
      );

      final movedChild = controller.lookupNode(childQuadId)!;
      expect((movedChild.transformPivot.dx - 160).abs() < 1e-6, isTrue);
      expect((movedChild.transformPivot.dy - 120).abs() < 1e-6, isTrue);
    });

    test('does not move detached child', () {
      final frameQuadId = controller.addNode(
        FrameNode(
          center: const ui.Offset(0, 0),
          width: 200,
          height: 200,
          style: const FrameNodeStyle(),
        ),
      );
      final childQuadId = controller.addNode(
        RectNode(
          center: const ui.Offset(20, 20),
          width: 30,
          height: 30,
          style: const RectNodeStyle(),
        ),
      );

      bridge.promoteRuntimeNodeAsEntity(frameQuadId, nodeId: 'frame');
      final childId = bridge.promoteRuntimeNodeAsEntity(
        childQuadId,
        nodeId: 'child',
      );
      documentState.upsertNode(
        documentState
            .nodeById(childId)!
            .copyWith(clearParentId: true, clearContainment: true),
      );

      final snapshots = <String, ui.Offset>{};
      propagateFrameChildMotion(
        controller: controller,
        documentState: documentState,
        runtimeBridge: bridge,
        framePivotSnapshotByNodeId: snapshots,
      );

      final frameNode = controller.lookupNode(frameQuadId)!;
      frameNode.translateWorld(const ui.Offset(80, 80));
      controller.updateNode(frameQuadId);

      propagateFrameChildMotion(
        controller: controller,
        documentState: documentState,
        runtimeBridge: bridge,
        framePivotSnapshotByNodeId: snapshots,
      );

      final childNode = controller.lookupNode(childQuadId)!;
      expect((childNode.transformPivot.dx - 20).abs() < 1e-6, isTrue);
      expect((childNode.transformPivot.dy - 20).abs() < 1e-6, isTrue);
    });
  });
}
