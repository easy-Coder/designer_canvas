import 'package:designer_canvas/document/canvas_document_state.dart';
import 'package:designer_canvas/document/document_codec.dart';
import 'package:designer_canvas/document/node_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDocumentState', () {
    test('round-trips through DocumentCodec', () {
      final doc = CanvasDocumentState(docId: 'doc-1', createdAtEpochMs: 1);
      final frame = NodeEntity(
        id: 'frame-1',
        type: NodeEntityType.frame,
        label: 'Frame',
        zIndex: 0,
        visible: true,
        locked: false,
        transform: const NodeTransformData(
          pivotX: 100,
          pivotY: 100,
          rotationRadians: 0,
        ),
        geometry: const {
          'centerX': 100.0,
          'centerY': 100.0,
          'width': 300.0,
          'height': 200.0,
          'rotationRadians': 0.0,
        },
        style: const {
          'kind': 'frame',
          'fill': {'color': 0x14B0BEC5},
        },
      );
      final child = NodeEntity(
        id: 'rect-1',
        type: NodeEntityType.rect,
        label: 'Rect',
        zIndex: 2,
        visible: true,
        locked: false,
        transform: const NodeTransformData(
          pivotX: 120,
          pivotY: 130,
          rotationRadians: 0,
        ),
        geometry: const {
          'centerX': 120.0,
          'centerY': 130.0,
          'width': 80.0,
          'height': 60.0,
          'rotationRadians': 0.0,
        },
        style: const {
          'kind': 'rect',
          'fill': {'color': 0xFFE65100},
        },
        parentId: 'frame-1',
        containment: const NodeContainmentData(
          localPivotX: 20,
          localPivotY: 30,
        ),
      );
      doc.upsertNode(frame, notify: false);
      doc.upsertNode(child, notify: false);

      final codec = DocumentCodec();
      final encoded = codec.toJson(doc);
      final decoded = codec.fromJson(encoded);

      expect(decoded.docId, 'doc-1');
      expect(decoded.nodesById.length, 2);
      expect(decoded.parentOf('rect-1'), 'frame-1');
      expect(decoded.childrenOf('frame-1'), contains('rect-1'));
      expect(decoded.validateInvariants(), isEmpty);
    });

    test('reports cycles in relationship indexes', () {
      final doc = CanvasDocumentState(docId: 'doc-cycle');
      doc.upsertNode(
        NodeEntity(
          id: 'a',
          type: NodeEntityType.frame,
          label: 'A',
          zIndex: 0,
          visible: true,
          locked: false,
          transform: const NodeTransformData(
            pivotX: 0,
            pivotY: 0,
            rotationRadians: 0,
          ),
          geometry: const {},
          style: const {'kind': 'frame'},
          parentId: 'b',
        ),
        notify: false,
      );
      doc.upsertNode(
        NodeEntity(
          id: 'b',
          type: NodeEntityType.frame,
          label: 'B',
          zIndex: 0,
          visible: true,
          locked: false,
          transform: const NodeTransformData(
            pivotX: 0,
            pivotY: 0,
            rotationRadians: 0,
          ),
          geometry: const {},
          style: const {'kind': 'frame'},
          parentId: 'a',
        ),
        notify: false,
      );

      final issues = doc.validateInvariants();
      expect(issues.any((e) => e.startsWith('cycle:')), isTrue);
    });
  });
}
