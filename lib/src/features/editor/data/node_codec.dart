import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/arrow_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/circle_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/image_placeholder_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/star_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';
import 'package:designer_canvas/src/features/editor/service/node_id_generator.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

class NodeCodec {
  NodeCodec({NodeIdGenerator? idGenerator})
    : _idGenerator = idGenerator ?? NodeIdGenerator();

  final NodeIdGenerator _idGenerator;

  NodeId newNodeId() => _idGenerator.nextId();

  NodeEntity entityFromNode(
    CanvasNode node, {
    NodeId? nodeId,
    NodeId? parentId,
    NodeContainmentData? containment,
  }) {
    final id = nodeId ?? newNodeId();
    final styleJson = node.style.toJson();
    if (node is ArrowNode) {
      final halfLength = node.rectWidth / 2;
      final dx = math.cos(node.rotationRadians) * halfLength;
      final dy = math.sin(node.rotationRadians) * halfLength;
      final start = ui.Offset(node.rectCenter.dx - dx, node.rectCenter.dy - dy);
      final end = ui.Offset(node.rectCenter.dx + dx, node.rectCenter.dy + dy);
      return NodeEntity(
        id: id,
        type: NodeEntityType.arrow,
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
    if (node is PolygonNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.polygon,
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
          'sides': node.polyStyle.side,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
    if (node is StarNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.star,
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
    if (node is ImageNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.image,
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
          'sourceFileName': node.sourceFileName,
          'sourceFilePath': node.sourceFilePath,
          'intrinsicWidth': node.intrinsicWidth,
          'intrinsicHeight': node.intrinsicHeight,
        },
        style: styleJson,
        parentId: parentId,
        containment: containment,
      );
    }
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
    if (node is PolygonNode) {
      return NodeEntity(
        id: id,
        type: NodeEntityType.polygon,
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
    if (node is LineNode && node is! ArrowNode) {
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
      case NodeEntityType.arrow:
        return ArrowNode(
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
      case NodeEntityType.polygon:
        return PolygonNode(
          center: ui.Offset(
            (entity.geometry['centerX'] as num?)?.toDouble() ?? 0,
            (entity.geometry['centerY'] as num?)?.toDouble() ?? 0,
          ),
          width: (entity.geometry['width'] as num?)?.toDouble() ?? 1,
          height: (entity.geometry['height'] as num?)?.toDouble() ?? 1,
          rotationRadians:
              (entity.geometry['rotationRadians'] as num?)?.toDouble() ?? 0,
          style: PolygonNodeStyle.fromJson(entity.style),
          label: entity.label,
          zIndex: entity.zIndex,
        );
      case NodeEntityType.star:
        return StarNode(
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
      case NodeEntityType.image:
        return ImageNode(
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
          sourceFileName: entity.geometry['sourceFileName'] as String?,
          sourceFilePath: entity.geometry['sourceFilePath'] as String?,
          intrinsicWidth: (entity.geometry['intrinsicWidth'] as num?)
              ?.toDouble(),
          intrinsicHeight: (entity.geometry['intrinsicHeight'] as num?)
              ?.toDouble(),
        );
    }
  }
}
