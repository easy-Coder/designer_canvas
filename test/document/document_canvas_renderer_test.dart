import 'dart:ui' as ui;

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/node_codec.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

void main() {
  group('DocumentCanvasRenderer selection preservation', () {
    late InfiniteCanvasController controller;
    late CanvasDocumentState document;
    late NodeCodec codec;
    late DocumentCanvasRenderer renderer;

    setUp(() {
      controller = InfiniteCanvasController()
        ..setWorldBounds(const ui.Rect.fromLTWH(-2000, -2000, 4000, 4000));
      document = CanvasDocumentState(docId: 'doc-render');
      codec = NodeCodec();
      renderer = DocumentCanvasRenderer(
        controller: controller,
        documentState: document,
        nodeCodec: codec,
      );

      document.addNode(
        LeafNodeEntity(
          id: 'a',
          name: 'A',
          pos: const NodePos(0, 0),
          metadata: const {'width': 50.0, 'height': 50.0, 'kind': 'rect'},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );
      document.addNode(
        LeafNodeEntity(
          id: 'b',
          name: 'B',
          pos: const NodePos(100, 0),
          metadata: const {'width': 50.0, 'height': 50.0, 'kind': 'rect'},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );
      renderer.rebuildFromDocument();
    });

    tearDown(() {
      renderer.dispose();
      controller.dispose();
      document.dispose();
    });

    test(
      'multi-selection survives a batched commit that replaces both nodes',
      () {
        final aQuadBefore = renderer.quadIdForNodeId('a')!;
        final bQuadBefore = renderer.quadIdForNodeId('b')!;
        controller.setSelection(
          {aQuadBefore, bQuadBefore},
          primary: aQuadBefore,
        );
        expect(controller.selectedQuadIds.length, 2);

        // Mutate both entities silently, then notify once. This mirrors
        // the gesture commit path which calls replaceEntity(notify: false)
        // for every dragged node and then a single emitChange().
        final a = document.nodeById('a')! as LeafNodeEntity;
        final b = document.nodeById('b')! as LeafNodeEntity;
        document.replaceEntity(
          a.copyWith(pos: const NodePos(10, 10)),
          notify: false,
        );
        document.replaceEntity(
          b.copyWith(pos: const NodePos(110, 10)),
          notify: false,
        );
        document.emitChange();

        expect(controller.selectedQuadIds.length, 2);
        final remappedSelected = controller.selectedQuadIds
            .map(renderer.nodeIdForQuadId)
            .whereType<String>()
            .toSet();
        expect(remappedSelected, {'a', 'b'});

        final primaryQuad = controller.primaryQuadId;
        expect(primaryQuad, isNotNull);
        expect(renderer.nodeIdForQuadId(primaryQuad!), 'a');
      },
    );

    test('selection of one replaced node keeps that single selection', () {
      final aQuadBefore = renderer.quadIdForNodeId('a')!;
      controller.selectSingle(aQuadBefore);

      final a = document.nodeById('a')! as LeafNodeEntity;
      document.replaceEntity(a.copyWith(pos: const NodePos(7, 7)));

      expect(controller.selectedQuadIds.length, 1);
      final primaryQuad = controller.primaryQuadId!;
      expect(renderer.nodeIdForQuadId(primaryQuad), 'a');
    });

    test('removing a selected node removes it from runtime selection', () {
      final aQuadBefore = renderer.quadIdForNodeId('a')!;
      final bQuadBefore = renderer.quadIdForNodeId('b')!;
      controller.setSelection(
        {aQuadBefore, bQuadBefore},
        primary: aQuadBefore,
      );

      document.removeNode('a');

      final remapped = controller.selectedQuadIds
          .map(renderer.nodeIdForQuadId)
          .whereType<String>()
          .toSet();
      expect(remapped, {'b'});
    });
  });
}
