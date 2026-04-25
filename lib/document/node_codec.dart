import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';
import 'package:uuid/uuid.dart';

import '../circle_node.dart';
import '../frame_node.dart';
import '../line_node.dart';
import '../node_styles.dart';
import '../rect_node.dart';
import '../text_node.dart';
import '../triangle_node.dart';
import 'node_entity.dart';

class NodeCodec {
  NodeCodec({Uuid? uuidGenerator}) : _uuid = uuidGenerator ?? const Uuid();

  final Uuid _uuid;

  NodeId newNodeId() => _uuid.v4();

  NodeEntity entityFromNode(
    CanvasNode node, {
    NodeId? nodeId,
    NodeId? parentId,
    NodeContainmentData? containment,
  }) {
    final id = nodeId ?? newNodeId();
    final styleJson = node.style.toJson();
    if (node is RectNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.rect,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: node.rotationRadians,
        ),
        geometry: {
          'centerX': node.rectCenter.dx,
          'centerY': node.rectCenter.dy,
          'width': node.rectWidth,
          'height': node.rectHeight,
          'rotationRadians': node.rotationRadians,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is FrameNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.frame,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: node.rotationRadians,
        ),
        geometry: {
          'centerX': node.rectCenter.dx,
          'centerY': node.rectCenter.dy,
          'width': node.rectWidth,
          'height': node.rectHeight,
          'rotationRadians': node.rotationRadians,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is CircleNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.circle,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: 0,
        ),
        geometry: {
          'centerX': node.rectCenter.dx,
          'centerY': node.rectCenter.dy,
          'radius': node.rectWidth / 2,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is TriangleNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.triangle,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: node.rotationRadians,
        ),
        geometry: {
          'centerX': node.rectCenter.dx,
          'centerY': node.rectCenter.dy,
          'side': node.rectWidth,
          'rotationRadians': node.rotationRadians,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is LineNode) {
      final halfLength = node.rectWidth / 2;
      final dx = math.cos(node.rotationRadians) * halfLength;
      final dy = math.sin(node.rotationRadians) * halfLength;
      final start = ui.Offset(node.rectCenter.dx - dx, node.rectCenter.dy - dy);
      final end = ui.Offset(node.rectCenter.dx + dx, node.rectCenter.dy + dy);
      return NodeEntity(
        id: id,
        type: NodeEntityType.line,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: node.rotationRadians,
        ),
        geometry: {
          'startX': start.dx,
          'startY': start.dy,
          'endX': end.dx,
          'endY': end.dy,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is TextNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.text,
        label: node.label,
        zIndex: node.zIndex,
        visible: true,
        locked: false,
        transform: NodeTransformData(
          pivotX: node.rectCenter.dx,
          pivotY: node.rectCenter.dy,
          rotationRadians: node.rotationRadians,
        ),
        geometry: {
          'left': node.bounds.left,
          'top': node.bounds.top,
          'rotationRadians': node.rotationRadians,
        },
        style: styleJson,
        text: node.text,
        parentId: parentId,
        containment: containment,
      );
    }
    return NodeEntity(
      id: id,
      type: NodeEntityType.rect,
      label: node.label,
      zIndex: node.zIndex,
      visible: true,
      locked: false,
      transform: const NodeTransformData(
        pivotX: 0,
        pivotY: 0,
        rotationRadians: 0,
      ),
      geometry: const <String, dynamic>{},
      style: styleJson,
      parentId: parentId,
      containment: containment,
    );
  }

  CanvasNode nodeFromEntity(NodeEntity entity) {
    switch (entity.type) {
      case NodeEntityType.rect:
        return RectNode(
          center: ui.Offset(
            (entity.geometry['centerX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['centerY'] as num?)?.toDouble() ?? 0,
          ),
          width: (entity.geometry['width'] as num?)?.toDouble() ?? 1,
          height: (entity.geometry['height'] as num?)?.toDouble() ?? 1,
          rotationRadians:
              (entity.geometry['rotationRadians'] as num?)?.toDouble() ?? 0,
          style: RectNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.frame:
        return FrameNode(
          center: ui.Offset(
            (entity.geometry['centerX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['centerY'] as num?)?.toDouble() ?? 0,
          ),
          width: (entity.geometry['width'] as num?)?.toDouble() ?? 1,
          height: (entity.geometry['height'] as num?)?.toDouble() ?? 1,
          style: FrameNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.circle:
        return CircleNode(
          center: ui.Offset(
            (entity.geometry['centerX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['centerY'] as num?)?.toDouble() ?? 0,
          ),
          radius: (entity.geometry['radius'] as num?)?.toDouble() ?? 1,
          style: CircleNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.triangle:
        return TriangleNode(
          center: ui.Offset(
            (entity.geometry['centerX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['centerY'] as num?)?.toDouble() ?? 0,
          ),
          side: (entity.geometry['side'] as num?)?.toDouble() ?? 1,
          rotationRadians:
              (entity.geometry['rotationRadians'] as num?)?.toDouble() ?? 0,
          style: TriangleNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.line:
        return LineNode(
          start: ui.Offset(
            (entity.geometry['startX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['startY'] as num?)?.toDouble() ?? 0,
          ),
          end: ui.Offset(
            (entity.geometry['endX'] as num?)?.toDouble() ?? 1,
            (entity.geometry['endY'] as num?)?.toDouble() ?? 0,
          ),
          style: LineNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.text:
        final left = (entity.geometry['left'] as num?)?.toDouble() ?? 0;
        final top = (entity.geometry['top'] as num?)?.toDouble() ?? 0;
        final node = TextNode(
          position: ui.Offset(left, top),
          text: entity.text ?? '',
          style: TextNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
        final targetRot =
            (entity.geometry['rotationRadians'] as num?)?.toDouble() ?? 0;
        if (targetRot != 0) {
          node.rotateWorldAround(node.transformPivot, targetRot);
        }
        return node;
    }
  }
}
