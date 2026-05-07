import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/document_codec.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDocumentState', () {
    test('round-trips through DocumentCodec', () {
      final doc = CanvasDocumentState(docId: 'doc-1', createdAtEpochMs: 1);
      final frame = FrameNodeEntity(
        id: 'frame-1',
        name: 'Frame',
        pos: const NodePos(0, 0),
        metadata: const {
          'kind': 'frame',
          'fill': {'color': 0x14B0BEC5},
          'width': 300.0,
          'height': 200.0,
          'rotation': 0.0,
          'zIndex': 0,
        },
        children: const ['rect-1'],
      );
      final child = LeafNodeEntity(
        id: 'rect-1',
        name: 'Rect',
        pos: const NodePos(100, 110),
        metadata: const {
          'kind': 'rect',
          'fill': {'color': 0xFFE65100},
          'width': 80.0,
          'height': 60.0,
          'rotation': 0.0,
          'zIndex': 2,
        },
        type: NodeEntityType.rect,
      );
      doc.addNode(frame, notify: false);
      doc.addNode(child, parentFrameId: 'frame-1', notify: false);

      final codec = DocumentCodec();
      final encoded = codec.toJson(doc);
      final decoded = codec.fromJson(encoded);

      expect(decoded.docId, 'doc-1');
      expect(decoded.nodesById.length, 2);
      expect(decoded.parentOf('rect-1'), 'frame-1');
      expect(decoded.childrenOf('frame-1'), contains('rect-1'));
      final restoredFrame = decoded.nodeById('frame-1');
      expect(restoredFrame, isA<FrameNodeEntity>());
      final restoredChild = decoded.nodeById('rect-1');
      expect(restoredChild, isA<LeafNodeEntity>());
      expect((restoredChild as LeafNodeEntity).type, NodeEntityType.rect);
      expect(decoded.validateInvariants(), isEmpty);
    });

    test('reports cycles in frame children', () {
      final doc = CanvasDocumentState(docId: 'doc-cycle');
      doc.addNode(
        FrameNodeEntity(
          id: 'a',
          name: 'A',
          pos: const NodePos(0, 0),
          metadata: const {'kind': 'frame'},
          children: const ['b'],
        ),
        notify: false,
      );
      doc.addNode(
        FrameNodeEntity(
          id: 'b',
          name: 'B',
          pos: const NodePos(0, 0),
          metadata: const {'kind': 'frame'},
          children: const ['a'],
        ),
        notify: false,
      );

      final issues = doc.validateInvariants();
      expect(issues.any((e) => e.startsWith('cycle:')), isTrue);
    });

    test('JSON keeps the children array on frames only', () {
      final doc = CanvasDocumentState(docId: 'doc-2');
      doc.addNode(
        FrameNodeEntity(
          id: 'f',
          name: 'F',
          pos: const NodePos(10, 20),
          metadata: const {'width': 100.0, 'height': 50.0},
          children: const ['child-1'],
        ),
        notify: false,
      );
      doc.addNode(
        LeafNodeEntity(
          id: 'child-1',
          name: 'Rect',
          pos: const NodePos(15, 25),
          metadata: const {'width': 30.0, 'height': 20.0},
          type: NodeEntityType.rect,
        ),
        parentFrameId: 'f',
        notify: false,
      );

      final json = doc.toJson();
      final nodesJson =
          (json['nodes'] as Map).cast<String, Map<String, dynamic>>();
      expect(nodesJson['f']!['children'], <String>['child-1']);
      expect(nodesJson['child-1']!.containsKey('children'), isFalse);
    });
  });
}
