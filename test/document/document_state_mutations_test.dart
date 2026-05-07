import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDocumentState mutations', () {
    test('setPos cascades through nested frames', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        FrameNodeEntity(
          id: 'outer',
          name: 'Outer',
          pos: const NodePos(0, 0),
          metadata: const {'width': 200.0, 'height': 200.0},
          children: const ['inner', 'leaf'],
        ),
        notify: false,
      );
      doc.addNode(
        FrameNodeEntity(
          id: 'inner',
          name: 'Inner',
          pos: const NodePos(20, 20),
          metadata: const {'width': 100.0, 'height': 100.0},
          children: const ['nested'],
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'leaf',
          name: 'Leaf',
          pos: const NodePos(150, 150),
          metadata: const {'width': 10.0, 'height': 10.0},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'nested',
          name: 'Nested',
          pos: const NodePos(40, 40),
          metadata: const {'width': 5.0, 'height': 5.0},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );
      doc.emitChange();

      doc.setPos('outer', 30, 50);

      expect(doc.nodeById('outer')!.pos, const NodePos(30, 50));
      expect(doc.nodeById('inner')!.pos, const NodePos(50, 70));
      expect(doc.nodeById('leaf')!.pos, const NodePos(180, 200));
      expect(doc.nodeById('nested')!.pos, const NodePos(70, 90));
    });

    test('setPos translates line endpoints stored in metadata', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        LeafNodeEntity(
          id: 'l',
          name: 'Line',
          pos: const NodePos(10, 10),
          metadata: const {
            'startX': 10.0,
            'startY': 10.0,
            'endX': 50.0,
            'endY': 30.0,
          },
          type: NodeEntityType.line,
        ),
        notify: false,
      );

      doc.setPos('l', 100, 110);

      final entity = doc.nodeById('l')!;
      expect(entity.pos, const NodePos(100, 110));
      expect(entity.metadata['startX'], 100.0);
      expect(entity.metadata['startY'], 110.0);
      expect(entity.metadata['endX'], 140.0);
      expect(entity.metadata['endY'], 130.0);
    });

    test('addChild rejects cycles', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        FrameNodeEntity(
          id: 'a',
          name: 'A',
          pos: const NodePos(0, 0),
          metadata: const {},
          children: const ['b'],
        ),
        notify: false,
      );
      doc.addNode(
        FrameNodeEntity(
          id: 'b',
          name: 'B',
          pos: const NodePos(0, 0),
          metadata: const {},
        ),
        parentFrameId: 'a',
        notify: false,
      );

      expect(() => doc.addChild('b', 'a'), throwsStateError);
    });

    test('addChild detaches from previous parent', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        FrameNodeEntity(
          id: 'f1',
          name: 'F1',
          pos: const NodePos(0, 0),
          metadata: const {},
        ),
        notify: false,
      );
      doc.addNode(
        FrameNodeEntity(
          id: 'f2',
          name: 'F2',
          pos: const NodePos(0, 0),
          metadata: const {},
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'leaf',
          name: 'Leaf',
          pos: const NodePos(0, 0),
          metadata: const {},
          type: NodeEntityType.rect,
        ),
        parentFrameId: 'f1',
        notify: false,
      );

      doc.addChild('f2', 'leaf');

      expect(doc.parentOf('leaf'), 'f2');
      expect(doc.childrenOf('f1'), isEmpty);
      expect(doc.childrenOf('f2'), <String>['leaf']);
    });

    test('removeNode cleans up parent frame children', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        FrameNodeEntity(
          id: 'frame',
          name: 'Frame',
          pos: const NodePos(0, 0),
          metadata: const {},
          children: const ['leaf'],
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'leaf',
          name: 'Leaf',
          pos: const NodePos(0, 0),
          metadata: const {},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );

      doc.removeNode('leaf');

      expect(doc.containsNode('leaf'), isFalse);
      expect(doc.childrenOf('frame'), isEmpty);
    });

    test('removing a frame deletes its descendants', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        FrameNodeEntity(
          id: 'f',
          name: 'F',
          pos: const NodePos(0, 0),
          metadata: const {},
          children: const ['inner'],
        ),
        notify: false,
      );
      doc.addNode(
        FrameNodeEntity(
          id: 'inner',
          name: 'Inner',
          pos: const NodePos(0, 0),
          metadata: const {},
          children: const ['leaf'],
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'leaf',
          name: 'Leaf',
          pos: const NodePos(0, 0),
          metadata: const {},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );

      doc.removeNode('f');

      expect(doc.containsNode('f'), isFalse);
      expect(doc.containsNode('inner'), isFalse);
      expect(doc.containsNode('leaf'), isFalse);
    });

    test('patchMetadata shallow-merges keys', () {
      final doc = CanvasDocumentState(docId: 'doc');
      doc.addNode(
        LeafNodeEntity(
          id: 'r',
          name: 'R',
          pos: const NodePos(0, 0),
          metadata: const {'width': 10.0, 'height': 20.0, 'kind': 'rect'},
          type: NodeEntityType.rect,
        ),
        notify: false,
      );

      doc.patchMetadata('r', {'width': 30.0, 'rotation': 1.0});

      final entity = doc.nodeById('r')!;
      expect(entity.metadata['width'], 30.0);
      expect(entity.metadata['height'], 20.0);
      expect(entity.metadata['kind'], 'rect');
      expect(entity.metadata['rotation'], 1.0);
    });
  });
}
