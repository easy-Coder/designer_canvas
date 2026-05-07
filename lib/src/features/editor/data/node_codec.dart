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

/// Builds runtime [CanvasNode] instances from document [NodeEntity] records.
///
/// This codec is one-way (document → runtime). Runtime mutations are no
/// longer reflected back into entities; instead, gestures and the inspector
/// dispatch typed mutations to [CanvasDocumentState] which then notifies the
/// renderer to rebuild the runtime node.
class NodeCodec {
  NodeCodec({NodeIdGenerator? idGenerator})
      : _idGenerator = idGenerator ?? NodeIdGenerator();

  final NodeIdGenerator _idGenerator;

  /// Mints a fresh document id for a brand-new node.
  NodeId newNodeId() => _idGenerator.nextId();

  /// Builds a runtime [CanvasNode] for the given entity. The returned node
  /// is unattached; callers add it to the [InfiniteCanvasController] via
  /// `controller.addNode(...)`.
  CanvasNode nodeFromEntity(NodeEntity entity) {
    final m = entity.metadata;
    final pos = entity.pos;
    switch (entity.type) {
      case NodeEntityType.rect:
        final w = _double(m['width'], 1);
        final h = _double(m['height'], 1);
        final rot = _double(m['rotation'], 0);
        return RectNode(
          center: _centerFromTopLeft(pos, w, h),
          width: w,
          height: h,
          rotationRadians: rot,
          style: RectNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.frame:
        final w = _double(m['width'], 1);
        final h = _double(m['height'], 1);
        return FrameNode(
          center: _centerFromTopLeft(pos, w, h),
          width: w,
          height: h,
          style: FrameNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.circle:
        final radius = _double(m['radius'], 1);
        final w = radius * 2;
        return CircleNode(
          center: _centerFromTopLeft(pos, w, w),
          radius: radius,
          style: CircleNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.line:
        return LineNode(
          start: ui.Offset(
            _double(m['startX'], pos.x),
            _double(m['startY'], pos.y),
          ),
          end: ui.Offset(
            _double(m['endX'], pos.x + 1),
            _double(m['endY'], pos.y),
          ),
          style: LineNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.arrow:
        return ArrowNode(
          start: ui.Offset(
            _double(m['startX'], pos.x),
            _double(m['startY'], pos.y),
          ),
          end: ui.Offset(
            _double(m['endX'], pos.x + 1),
            _double(m['endY'], pos.y),
          ),
          style: LineNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.polygon:
        final w = _double(m['width'], 1);
        final h = _double(m['height'], 1);
        final rot = _double(m['rotation'], 0);
        return PolygonNode(
          center: _centerFromTopLeft(pos, w, h),
          width: w,
          height: h,
          rotationRadians: rot,
          style: PolygonNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.star:
        final w = _double(m['width'], 1);
        final h = _double(m['height'], 1);
        final rot = _double(m['rotation'], 0);
        return StarNode(
          center: _centerFromTopLeft(pos, w, h),
          width: w,
          height: h,
          rotationRadians: rot,
          style: RectNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );

      case NodeEntityType.image:
        final w = _double(m['width'], 1);
        final h = _double(m['height'], 1);
        final rot = _double(m['rotation'], 0);
        return ImageNode(
          center: _centerFromTopLeft(pos, w, h),
          width: w,
          height: h,
          rotationRadians: rot,
          style: RectNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
          sourceFileName: m['sourceFileName'] as String?,
          sourceFilePath: m['sourceFilePath'] as String?,
          intrinsicWidth: (m['intrinsicWidth'] as num?)?.toDouble(),
          intrinsicHeight: (m['intrinsicHeight'] as num?)?.toDouble(),
        );

      case NodeEntityType.text:
        final node = TextNode(
          position: ui.Offset(pos.x, pos.y),
          text: (m['text'] as String?) ?? '',
          style: TextNodeStyle.fromJson(m),
          label: entity.name,
          zIndex: _int(m['zIndex'], 0),
        );
        final rot = _double(m['rotation'], 0);
        if (rot != 0) {
          node.rotateWorldAround(node.transformPivot, rot);
        }
        return node;
    }
  }

  /// Builds a [LeafNodeEntity] from a runtime axis-aligned rect placement.
  ///
  /// `metadataExtras` lets shape-specific extras (e.g. `cornerRadius`) merge
  /// in. Used by tool placement to avoid first-creating a runtime node and
  /// then promoting it.
  LeafNodeEntity rectLikeEntity({
    required NodeId id,
    required NodeEntityType type,
    required String name,
    required ui.Rect rect,
    required NodeStyle style,
    int zIndex = 0,
    double rotation = 0,
    Map<String, dynamic> metadataExtras = const <String, dynamic>{},
  }) {
    return LeafNodeEntity(
      id: id,
      name: name,
      pos: NodePos(rect.left, rect.top),
      metadata: <String, dynamic>{
        ...style.toJson(),
        'width': rect.width,
        'height': rect.height,
        'rotation': rotation,
        'zIndex': zIndex,
        ...metadataExtras,
      },
      type: type,
    );
  }

  /// Builds a [FrameNodeEntity] from an axis-aligned rect placement.
  FrameNodeEntity frameEntity({
    required NodeId id,
    required String name,
    required ui.Rect rect,
    required FrameNodeStyle style,
    int zIndex = 0,
  }) {
    return FrameNodeEntity(
      id: id,
      name: name,
      pos: NodePos(rect.left, rect.top),
      metadata: <String, dynamic>{
        ...style.toJson(),
        'width': rect.width,
        'height': rect.height,
        'rotation': 0,
        'zIndex': zIndex,
      },
    );
  }

  /// Builds a circle entity from world-space center and radius.
  LeafNodeEntity circleEntity({
    required NodeId id,
    required String name,
    required ui.Offset center,
    required double radius,
    required CircleNodeStyle style,
    int zIndex = 0,
  }) {
    final r = math.max(radius, 1e-6);
    return LeafNodeEntity(
      id: id,
      name: name,
      pos: NodePos(center.dx - r, center.dy - r),
      metadata: <String, dynamic>{
        ...style.toJson(),
        'radius': r,
        'zIndex': zIndex,
      },
      type: NodeEntityType.circle,
    );
  }

  /// Builds a line entity from world-space endpoints. `pos` is set to the
  /// axis-aligned bbox top-left so it stays consistent with other shapes;
  /// the endpoints themselves live in metadata.
  LeafNodeEntity lineEntity({
    required NodeId id,
    required String name,
    required ui.Offset start,
    required ui.Offset end,
    required LineNodeStyle style,
    int zIndex = 0,
    bool arrow = false,
  }) {
    return LeafNodeEntity(
      id: id,
      name: name,
      pos: NodePos(
        math.min(start.dx, end.dx),
        math.min(start.dy, end.dy),
      ),
      metadata: <String, dynamic>{
        ...style.toJson(),
        'startX': start.dx,
        'startY': start.dy,
        'endX': end.dx,
        'endY': end.dy,
        'zIndex': zIndex,
      },
      type: arrow ? NodeEntityType.arrow : NodeEntityType.line,
    );
  }

  /// Builds a text entity from a top-left anchor.
  LeafNodeEntity textEntity({
    required NodeId id,
    required String name,
    required ui.Offset position,
    required String text,
    required TextNodeStyle style,
    int zIndex = 0,
  }) {
    return LeafNodeEntity(
      id: id,
      name: name,
      pos: NodePos(position.dx, position.dy),
      metadata: <String, dynamic>{
        ...style.toJson(),
        'text': text,
        'rotation': 0,
        'zIndex': zIndex,
      },
      type: NodeEntityType.text,
    );
  }

  /// Re-derives an entity's metadata + pos from its current runtime
  /// [CanvasNode]. Used when committing select-mode interactions into the
  /// document. Returns [baseline] verbatim (preserving identity) when
  /// nothing observable changed, so downstream identity-based skips are
  /// effective.
  NodeEntity entitySnapshotFor(
    NodeEntity baseline,
    CanvasNode node,
  ) {
    final newName = node.label;
    final newPos = _posFromRuntime(node, baseline.type);
    final newMeta = _metadataFromRuntime(node, baseline.type, baseline.metadata);
    if (newName == baseline.name &&
        newPos == baseline.pos &&
        _mapShallowEquals(newMeta, baseline.metadata)) {
      return baseline;
    }
    switch (baseline) {
      case LeafNodeEntity():
        return baseline.copyWith(
          name: newName,
          pos: newPos,
          metadata: newMeta,
        );
      case FrameNodeEntity():
        return baseline.copyWith(
          name: newName,
          pos: newPos,
          metadata: newMeta,
        );
    }
  }
}

/// Cheap shallow comparison adequate for metadata maps: same keys, equal
/// (==) values. Sub-maps (fill/stroke/shadow) are compared recursively
/// because they are typed structures whose elements are primitives.
bool _mapShallowEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final av = a[key];
    final bv = b[key];
    if (av is Map && bv is Map) {
      if (!_mapShallowEquals(
        av.cast<String, dynamic>(),
        bv.cast<String, dynamic>(),
      )) {
        return false;
      }
    } else if (av is List && bv is List) {
      if (av.length != bv.length) return false;
      for (var i = 0; i < av.length; i++) {
        if (av[i] != bv[i]) return false;
      }
    } else if (av != bv) {
      return false;
    }
  }
  return true;
}

NodePos _posFromRuntime(CanvasNode node, NodeEntityType type) {
  if (type == NodeEntityType.line || type == NodeEntityType.arrow) {
    final b = node.bounds;
    return NodePos(b.left, b.top);
  }
  if (node is RoundedRectCanvasMixin) {
    if (type == NodeEntityType.text) {
      // Text uses bounds top-left as its anchor.
      final b = node.bounds;
      return NodePos(b.left, b.top);
    }
    return NodePos(
      node.rectCenter.dx - node.rectWidth / 2,
      node.rectCenter.dy - node.rectHeight / 2,
    );
  }
  final b = node.bounds;
  return NodePos(b.left, b.top);
}

Map<String, dynamic> _metadataFromRuntime(
  CanvasNode node,
  NodeEntityType type,
  Map<String, dynamic> previous,
) {
  final next = <String, dynamic>{...previous};
  // Style fields always come from the runtime style.
  next.addAll(node.style.toJson());

  if (node is RoundedRectCanvasMixin) {
    next['width'] = node.rectWidth;
    next['height'] = node.rectHeight;
    next['rotation'] = node.rotationRadians;
  }
  if (node is CircleNode) {
    next['radius'] = node.rectWidth / 2;
  }
  if (node is LineNode) {
    final halfLength = node.rectWidth / 2;
    final dx = math.cos(node.rotationRadians) * halfLength;
    final dy = math.sin(node.rotationRadians) * halfLength;
    next['startX'] = node.rectCenter.dx - dx;
    next['startY'] = node.rectCenter.dy - dy;
    next['endX'] = node.rectCenter.dx + dx;
    next['endY'] = node.rectCenter.dy + dy;
  }
  if (node is ImageNode) {
    next['sourceFileName'] = node.sourceFileName;
    next['sourceFilePath'] = node.sourceFilePath;
    next['intrinsicWidth'] = node.intrinsicWidth;
    next['intrinsicHeight'] = node.intrinsicHeight;
  }
  if (node is TextNode) {
    next['text'] = node.text;
  }
  return next;
}

ui.Offset _centerFromTopLeft(NodePos pos, double width, double height) {
  return ui.Offset(pos.x + width / 2, pos.y + height / 2);
}

double _double(Object? raw, double fallback) {
  return (raw is num) ? raw.toDouble() : fallback;
}

int _int(Object? raw, int fallback) {
  return (raw is num) ? raw.toInt() : fallback;
}
