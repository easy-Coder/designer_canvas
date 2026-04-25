import 'dart:ui' as ui;

import 'package:designer_canvas/document/canvas_document_state.dart';
import 'package:designer_canvas/document/document_ops.dart';
import 'package:designer_canvas/document/document_reducer.dart';
import 'package:designer_canvas/document/node_codec.dart';
import 'package:designer_canvas/document/runtime_index_bridge.dart';
import 'package:designer_canvas/frame_node.dart';
import 'package:designer_canvas/node_styles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

void main() {
  group('placement preview → document commit', () {
    late InfiniteCanvasController controller;
    late CanvasDocumentState documentState;
    late RuntimeIndexBridge bridge;
    late DocumentReducer reducer;
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
      reducer = DocumentReducer(
        documentState: documentState,
        runtimeBridge: bridge,
      );
    });

    tearDown(() {
      controller.dispose();
      documentState.dispose();
    });

    test('NodeCreated + applyUpsert duplicates an unmapped preview quad (regression)', () {
      final previewQuad = controller.addNode(
        FrameNode(
          center: const ui.Offset(50, 60),
          width: 100,
          height: 80,
          style: const FrameNodeStyle(),
        ),
      );
      expect(controller.orderedNodes, hasLength(1));

      final node = controller.lookupNode(previewQuad)!;
      final nodeId = codec.newNodeId();
      final entity = codec.entityFromNode(node, nodeId: nodeId);
      reducer.dispatch(NodeCreated(entity));

      expect(
        controller.orderedNodes.length,
        2,
        reason: 'document path must add a second runtime node when preview was unmapped',
      );
    });

    test('promoteRuntimeNodeAsEntity keeps a single controller node (placement commit)', () {
      final previewQuad = controller.addNode(
        FrameNode(
          center: const ui.Offset(50, 60),
          width: 100,
          height: 80,
          style: const FrameNodeStyle(),
        ),
      );
      expect(controller.orderedNodes, hasLength(1));

      final nodeId = codec.newNodeId();
      bridge.promoteRuntimeNodeAsEntity(previewQuad, nodeId: nodeId);

      expect(controller.orderedNodes, hasLength(1));
      expect(bridge.nodeIdForQuadId(previewQuad), nodeId);
      expect(bridge.quadIdForNodeId(nodeId), previewQuad);
      expect(documentState.nodeById(nodeId), isNotNull);
    });
  });
}
