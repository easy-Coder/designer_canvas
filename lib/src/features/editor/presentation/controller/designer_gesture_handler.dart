import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/node_codec.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_size_presets.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/arrow_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/circle_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/image_placeholder_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/star_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';

import 'package:designer_canvas/src/features/editor/domain/tool_style_defaults.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/pending_image_placement.dart';
import 'package:designer_canvas/src/features/editor/presentation/editor_toolbar_metadata.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_input_config.dart';
import 'canvas_select_gestures.dart';

const int _kPrimaryMouseButton = 0x01;
const Duration _kDoubleClickTimeout = Duration(milliseconds: 350);
const double _kDoubleClickMaxDistance = 8.0;

/// Routes pointer/keyboard input for the designer.
///
/// Select-mode gestures delegate to [CanvasSelectGestures] (translate /
/// resize / rotate). Tool placement is handled here. After every gesture
/// commits, the runtime state is snapshotted into [CanvasDocumentState] —
/// the document is the single source of truth, the runtime quadtree is a
/// pure projection of it.
class DesignerGestureHandler {
  DesignerGestureHandler({
    required this.tool,
    required this.toolDefaults,
    required this.frameSizePreset,
    required this.documentState,
    required this.renderer,
    required this.nodeCodec,
    required this.selectGestures,
    required this.gestureConfig,
    required this.canvasFocusNode,
    required this.pendingImagePlacement,
    this.onToolActivated,
  });

  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;
  final ValueNotifier<FrameSizePreset> frameSizePreset;
  final CanvasDocumentState documentState;
  final DocumentCanvasRenderer renderer;
  final NodeCodec nodeCodec;
  final CanvasSelectGestures selectGestures;
  final DesignerCanvasInputConfig gestureConfig;
  final FocusNode canvasFocusNode;
  final ValueNotifier<PendingImagePlacement?> pendingImagePlacement;
  final void Function(CanvasTool tool)? onToolActivated;

  int? _textDragPointer;
  Duration? _lastTextPointerDownAt;
  ui.Offset? _lastTextPointerDownLocal;

  // ─── Live placement state ─────────────────────────────────────────────
  int? _placePointer;
  ui.Offset? _placeWorldStart;
  CanvasTool? _placeTool;
  int? _placeQuadId; // runtime preview only; never written to the document
  PendingImagePlacement? _placeImage;

  // Frame pivots tracked for visual coherence: while a frame is being
  // dragged we translate its runtime children by the same delta so they
  // appear glued to the frame. The document only learns of the move once
  // the gesture commits via [_commitSelectInteractionToDocument].
  final Map<NodeId, ui.Offset> _framePivotByNodeId = <NodeId, ui.Offset>{};

  /// Quad id of the node currently in inline text edit (if any).
  int? activeEditingQuadId(InfiniteCanvasController controller) =>
      controller.text.editingQuadId;

  /// Start inline editing for [node] at [quadId].
  void startEditing(
    int quadId,
    TextNode node,
    InfiniteCanvasController controller,
  ) {
    controller.text.beginEditing(quadId);
    canvasFocusNode.requestFocus();
  }

  void handleCanvasFocusChanged(
    bool hasFocus,
    InfiniteCanvasController controller,
  ) {
    if (!hasFocus && controller.text.editingQuadId == null) return;
  }

  void dispose() {}

  /// Commit current text and close the editor.
  void stopEditing(
    InfiniteCanvasController? controller, {
    required bool commit,
  }) {
    controller?.text.stopEditing(commit: commit);
    _textDragPointer = null;
    _lastTextPointerDownAt = null;
    _lastTextPointerDownLocal = null;
    if (commit && controller != null) {
      _commitSelectInteractionToDocument(controller);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  static ui.Rect _normalizeWorldRect(ui.Offset a, ui.Offset b) {
    return ui.Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }

  double _minWorldSize(InfiniteCanvasController controller) =>
      24 / controller.camera.zoomDouble;

  double _slopWorld(InfiniteCanvasController controller) =>
      gestureConfig.selectionSlopPixels / controller.camera.zoomDouble;

  double _previewSeed(InfiniteCanvasController controller) =>
      (1 / controller.camera.zoomDouble).clamp(1e-6, 100.0);

  void _clearPlacement() {
    _placePointer = null;
    _placeWorldStart = null;
    _placeTool = null;
    _placeQuadId = null;
    _placeImage = null;
  }

  void _switchToSelectTool() {
    if (tool.value != CanvasTool.select) {
      tool.value = CanvasTool.select;
    }
  }

  Iterable<(int, FrameNode)> _orderedFrames(
    InfiniteCanvasController controller,
  ) {
    final frames = <(int, FrameNode)>[];
    for (final (quadId, node) in controller.orderedNodes) {
      if (node is FrameNode) {
        frames.add((quadId, node));
      }
    }
    return frames;
  }

  NodeId? _nodeIdForQuadId(int quadId) => renderer.nodeIdForQuadId(quadId);

  int? _quadIdForNodeId(NodeId nodeId) => renderer.quadIdForNodeId(nodeId);

  // ─── Frame containment ─────────────────────────────────────────────────

  bool _canAssignToFrame(int childId, int frameId) {
    if (childId == frameId) return false;
    final childNodeId = _nodeIdForQuadId(childId);
    final frameNodeId = _nodeIdForQuadId(frameId);
    if (childNodeId == null || frameNodeId == null) return false;
    if (documentState.parentOf(frameNodeId) == childNodeId) return false;
    if (documentState.isDescendantOf(childNodeId, frameNodeId)) return false;
    return true;
  }

  int? _bestContainingFrame(
    InfiniteCanvasController controller,
    int childQuadId,
    CanvasNode childNode,
  ) {
    int? bestId;
    double? bestArea;
    final childBounds = childNode.bounds;
    for (final (frameId, frameNode) in _orderedFrames(controller)) {
      if (!_canAssignToFrame(childQuadId, frameId)) continue;
      if (!frameNode.bounds.contains(childBounds.topLeft) ||
          !frameNode.bounds.contains(childBounds.topRight) ||
          !frameNode.bounds.contains(childBounds.bottomLeft) ||
          !frameNode.bounds.contains(childBounds.bottomRight)) {
        continue;
      }
      final area = frameNode.bounds.width * frameNode.bounds.height;
      if (bestArea == null || area < bestArea) {
        bestArea = area;
        bestId = frameId;
      }
    }
    return bestId;
  }

  /// While a frame is being dragged in select mode we translate its
  /// document children's *runtime* nodes by the same delta so they appear
  /// glued to the frame during the drag. Document children positions are
  /// not changed here; the move gets committed via
  /// [_commitSelectInteractionToDocument] when the pointer is released.
  void _propagateFrameChildMotionInRuntime(
    InfiniteCanvasController controller,
  ) {
    final moved = <int>{};
    for (final (frameQuadId, frameNode) in _orderedFrames(controller)) {
      final frameNodeId = _nodeIdForQuadId(frameQuadId);
      if (frameNodeId == null) continue;
      final currentPivot = frameNode.transformPivot;
      final previousPivot = _framePivotByNodeId[frameNodeId];
      _framePivotByNodeId[frameNodeId] = currentPivot;
      if (previousPivot == null) continue;
      final delta = currentPivot - previousPivot;
      if (delta.distanceSquared < 1e-12) continue;
      for (final childNodeId in documentState.childrenOf(frameNodeId)) {
        final childQuadId = _quadIdForNodeId(childNodeId);
        if (childQuadId == null) continue;
        final childNode = controller.lookupNode(childQuadId);
        if (childNode == null) continue;
        // Skip children that the user is also dragging directly — they were
        // already translated by the package's selection gestures.
        if (controller.selectedQuadIds.contains(childQuadId)) continue;
        childNode.translateWorld(delta);
        moved.add(childQuadId);
      }
    }
    if (moved.isNotEmpty) {
      controller.relayoutNodes(moved);
    }
  }

  void _sweepFramePivotSnapshots(InfiniteCanvasController controller) {
    final activeFrameIds = <NodeId>{};
    for (final (frameQuadId, _) in _orderedFrames(controller)) {
      final frameNodeId = _nodeIdForQuadId(frameQuadId);
      if (frameNodeId != null) {
        activeFrameIds.add(frameNodeId);
      }
    }
    _framePivotByNodeId.removeWhere((id, _) => !activeFrameIds.contains(id));
  }

  // ─── Document commits ──────────────────────────────────────────────────

  /// Snapshots every runtime node into the document. Recomputes frame
  /// containment based on the new geometry. Called once per gesture commit.
  void _commitSelectInteractionToDocument(
    InfiniteCanvasController controller,
  ) {
    // Snapshot runtime geometry → entity for every known mapping.
    for (final entry in renderer.nodeIdByQuadId.entries.toList()) {
      final nodeId = entry.value;
      final node = controller.node.lookup(entry.key);
      if (node == null) continue;
      final current = documentState.nodeById(nodeId);
      if (current == null) continue;
      final next = nodeCodec.entitySnapshotFor(current, node);
      if (identical(current, next)) continue;
      documentState.replaceEntity(next, notify: false);
    }
    _recomputeFrameMembership(controller);
    _sweepFramePivotSnapshots(controller);
    documentState.emitChange();
  }

  /// After a select interaction, recompute which frame each node should
  /// belong to (or none) based on its committed geometry, and update the
  /// document accordingly.
  void _recomputeFrameMembership(InfiniteCanvasController controller) {
    for (final (quadId, node) in controller.orderedNodes) {
      if (node is FrameNode) continue;
      final childNodeId = _nodeIdForQuadId(quadId);
      if (childNodeId == null) continue;
      final bestFrameQuadId = _bestContainingFrame(controller, quadId, node);
      final bestFrameNodeId = bestFrameQuadId == null
          ? null
          : _nodeIdForQuadId(bestFrameQuadId);
      final currentParent = documentState.parentOf(childNodeId);
      if (currentParent == bestFrameNodeId) continue;
      if (currentParent != null) {
        documentState.removeChild(currentParent, childNodeId, notify: false);
      }
      if (bestFrameNodeId != null) {
        documentState.addChild(bestFrameNodeId, childNodeId, notify: false);
      }
    }
  }

  // ─── Tool placement (preview lives in runtime only) ─────────────────────

  void _beginPreviewNode(
    InfiniteCanvasController controller,
    ui.Offset start,
    CanvasTool t,
  ) {
    final eps = _previewSeed(controller);
    switch (t) {
      case CanvasTool.select:
        break;
      case CanvasTool.text:
        break;
      case CanvasTool.frame:
        final spec = frameSizePresetSpecs[frameSizePreset.value]!;
        final r = ui.Rect.fromCenter(
          center: start,
          width: spec.size.width,
          height: spec.size.height,
        );
        _placeQuadId = controller.node.add(
          FrameNode.fromAxisAlignedRect(
            r,
            style: toolDefaults.value.frame,
            zIndex: 0,
          ),
        );
      case CanvasTool.rect:
        final r = ui.Rect.fromCenter(center: start, width: eps, height: eps);
        _placeQuadId = controller.node.add(
          RectNode.fromAxisAlignedRect(
            r,
            style: toolDefaults.value.rect,
            zIndex: 2,
          ),
        );
      case CanvasTool.circle:
        _placeQuadId = controller.node.add(
          CircleNode(
            center: start,
            radius: eps / 2,
            style: toolDefaults.value.circle,
            zIndex: 2,
          ),
        );
      case CanvasTool.line:
      case CanvasTool.pen:
        _placeQuadId = controller.node.add(
          LineNode(
            start: start,
            end: ui.Offset(start.dx + eps, start.dy),
            style: toolDefaults.value.line,
            zIndex: 2,
          ),
        );
      case CanvasTool.arrow:
        _placeQuadId = controller.node.add(
          ArrowNode(
            start: start,
            end: ui.Offset(start.dx + eps, start.dy),
            style: toolDefaults.value.line,
            zIndex: 2,
          ),
        );
      case CanvasTool.polygon:
        _placeQuadId = controller.node.add(
          PolygonNode(
            center: start,
            width: eps,
            height: eps,
            style: toolDefaults.value.polygon,
            zIndex: 2,
          ),
        );
      case CanvasTool.star:
        _placeQuadId = controller.node.add(
          StarNode(
            center: start,
            width: eps,
            height: eps,
            style: toolDefaults.value.star,
            zIndex: 2,
          ),
        );
      case CanvasTool.image:
        _placeImage = pendingImagePlacement.value;
        _placeQuadId = controller.node.add(
          ImageNode(
            center: start,
            width: eps,
            height: eps,
            style: toolDefaults.value.image,
            zIndex: 2,
            sourceFileName: _placeImage?.fileName,
            sourceFilePath: _placeImage?.filePath,
            intrinsicWidth: _placeImage?.intrinsicWidth,
            intrinsicHeight: _placeImage?.intrinsicHeight,
          ),
        );
    }
  }

  void _applyPreviewGeometry(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end, {
    required bool lineFinalize,
  }) {
    final id = _placeQuadId;
    final t = _placeTool;
    if (id == null || t == null) return;

    final minW = _minWorldSize(controller);
    final node = controller.node.lookup(id);
    if (node == null) return;

    switch (t) {
      case CanvasTool.select:
      case CanvasTool.text:
        break;
      case CanvasTool.frame:
        (node as FrameNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.node.reindex(id);
      case CanvasTool.rect:
        (node as RectNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.node.reindex(id);
      case CanvasTool.circle:
        final r = _normalizeWorldRect(start, end);
        final radius = math.min(r.width, r.height) / 2;
        (node as CircleNode).setCenterAndRadius(r.center, radius);
        controller.node.reindex(id);
      case CanvasTool.line:
      case CanvasTool.pen:
      case CanvasTool.arrow:
        var a = start;
        var b = end;
        if (lineFinalize && (b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        (node as LineNode).setWorldEndpoints(a, b);
        controller.node.reindex(id);
      case CanvasTool.polygon:
        (node as PolygonNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.node.reindex(id);
      case CanvasTool.star:
        (node as StarNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.node.reindex(id);
      case CanvasTool.image:
        (node as ImageNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.node.reindex(id);
    }
  }

  bool _previewBelowMinSize(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
  ) {
    final minW = _minWorldSize(controller);
    final t = _placeTool;
    if (t == null) return true;
    switch (t) {
      case CanvasTool.rect:
      case CanvasTool.frame:
      case CanvasTool.circle:
      case CanvasTool.polygon:
      case CanvasTool.star:
      case CanvasTool.image:
        final r = _normalizeWorldRect(start, end);
        return r.width < minW || r.height < minW;
      case CanvasTool.select:
      case CanvasTool.text:
      case CanvasTool.line:
      case CanvasTool.pen:
      case CanvasTool.arrow:
        return false;
    }
  }

  /// Builds the entity for the just-completed placement gesture and
  /// dispatches it to the document. Returns the new node's runtime quad id
  /// (after the renderer projects the entity), or null if nothing was
  /// committed.
  NodeId? _commitPlacementToDocument(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
    CanvasTool t,
  ) {
    final preview = _placeQuadId;
    final defaults = toolDefaults.value;
    final id = nodeCodec.newNodeId();
    NodeEntity? entity;

    switch (t) {
      case CanvasTool.select:
      case CanvasTool.text:
        return null;
      case CanvasTool.frame:
        final spec = frameSizePresetSpecs[frameSizePreset.value]!;
        final slop = _slopWorld(controller);
        final rect = (end - start).distance <= slop
            ? ui.Rect.fromCenter(
                center: start,
                width: spec.size.width,
                height: spec.size.height,
              )
            : _normalizeWorldRect(start, end);
        entity = nodeCodec.frameEntity(
          id: id,
          name: 'Frame',
          rect: rect,
          style: defaults.frame,
        );
      case CanvasTool.rect:
        entity = nodeCodec.rectLikeEntity(
          id: id,
          type: NodeEntityType.rect,
          name: 'Rectangle',
          rect: _normalizeWorldRect(start, end),
          style: defaults.rect,
          zIndex: 2,
        );
      case CanvasTool.circle:
        final r = _normalizeWorldRect(start, end);
        final radius = math.min(r.width, r.height) / 2;
        entity = nodeCodec.circleEntity(
          id: id,
          name: 'Circle',
          center: r.center,
          radius: radius,
          style: defaults.circle,
          zIndex: 2,
        );
      case CanvasTool.line:
      case CanvasTool.pen:
        var a = start;
        var b = end;
        final minW = _minWorldSize(controller);
        if ((b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        entity = nodeCodec.lineEntity(
          id: id,
          name: 'Line',
          start: a,
          end: b,
          style: defaults.line,
          zIndex: 2,
        );
      case CanvasTool.arrow:
        var a = start;
        var b = end;
        final minW = _minWorldSize(controller);
        if ((b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        entity = nodeCodec.lineEntity(
          id: id,
          name: 'Arrow',
          start: a,
          end: b,
          style: defaults.line,
          zIndex: 2,
          arrow: true,
        );
      case CanvasTool.polygon:
        entity = nodeCodec.rectLikeEntity(
          id: id,
          type: NodeEntityType.polygon,
          name: 'Polygon',
          rect: _normalizeWorldRect(start, end),
          style: defaults.polygon,
          zIndex: 2,
        );
      case CanvasTool.star:
        entity = nodeCodec.rectLikeEntity(
          id: id,
          type: NodeEntityType.star,
          name: 'Star',
          rect: _normalizeWorldRect(start, end),
          style: defaults.star,
          zIndex: 2,
        );
      case CanvasTool.image:
        final selected = _placeImage;
        final slop = _slopWorld(controller);
        final clickPlacement = (end - start).distance <= slop;
        final rect = clickPlacement && selected != null
            ? ui.Rect.fromCenter(
                center: start,
                width: selected.intrinsicWidth,
                height: selected.intrinsicHeight,
              )
            : _normalizeWorldRect(start, end);
        if (selected == null) {
          if (preview != null) controller.node.remove(preview);
          return null;
        }
        entity = nodeCodec.rectLikeEntity(
          id: id,
          type: NodeEntityType.image,
          name: 'Image',
          rect: rect,
          style: defaults.image,
          zIndex: 2,
          metadataExtras: <String, dynamic>{
            'sourceFileName': selected.fileName,
            'sourceFilePath': selected.filePath,
            'intrinsicWidth': selected.intrinsicWidth,
            'intrinsicHeight': selected.intrinsicHeight,
          },
        );
    }

    // Drop the runtime preview before notifying the document; the renderer
    // will rebuild a real runtime node from the entity in the next listener
    // callback.
    if (preview != null) controller.node.remove(preview);
    documentState.addNode(entity);
    return id;
  }

  void _finalizePlacement(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
  ) {
    final t = _placeTool;
    final id = _placeQuadId;
    final slop = _slopWorld(controller);

    if (t == CanvasTool.text) {
      if ((end - start).distance <= slop) {
        final newId = nodeCodec.newNodeId();
        final entity = nodeCodec.textEntity(
          id: newId,
          name: 'Text',
          position: start,
          text: 'Text',
          style: toolDefaults.value.text,
          zIndex: 2,
        );
        documentState.addNode(entity);
        final quad = renderer.quadIdForNodeId(newId);
        if (quad != null) {
          controller.selection.selectSingle(quad);
          final node = controller.node.lookup(quad);
          if (node is TextNode) {
            startEditing(quad, node, controller);
          }
        }
        _switchToSelectTool();
      }
      controller.invalidate();
      return;
    }

    if (id == null || t == null || t == CanvasTool.select) {
      controller.invalidate();
      return;
    }

    if (_previewBelowMinSize(controller, start, end) &&
        t != CanvasTool.line &&
        t != CanvasTool.pen &&
        t != CanvasTool.arrow &&
        !(t == CanvasTool.frame && (end - start).distance <= slop) &&
        !(t == CanvasTool.image && (end - start).distance <= slop)) {
      controller.node.remove(id);
      controller.invalidate();
      return;
    }

    final newNodeId = _commitPlacementToDocument(controller, start, end, t);
    if (newNodeId != null) {
      final newQuadId = renderer.quadIdForNodeId(newNodeId);
      if (newQuadId != null) {
        controller.selection.selectSingle(newQuadId);
      }
      _switchToSelectTool();
    }
    controller.invalidate();
  }

  // ─── Pointer / keyboard entry points ──────────────────────────────────

  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    if (event is PointerScrollEvent || event is PointerPanZoomUpdateEvent) {
      selectGestures.handlePointerEvent(event, controller);
      return;
    }

    if (tool.value != CanvasTool.select) {
      controller.clearHover();
    }

    if (controller.text.editingQuadId != null && _textDragPointer != null) {
      if (event.pointer == _textDragPointer && event is PointerMoveEvent) {
        controller.text.dragSelectTo(
          event.localPosition,
          camera: controller.camera,
        );
        return;
      }
      if (event.pointer == _textDragPointer &&
          (event is PointerUpEvent || event is PointerCancelEvent)) {
        controller.text.endTextDrag();
        _textDragPointer = null;
        return;
      }
    }

    if (event is PointerDownEvent && controller.text.editingQuadId != null) {
      final node = controller.text.editingNode;
      if (node is TextNode) {
        final world = controller.camera.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        final toleranceWorld = 8.0 / controller.camera.zoomDouble;
        final hitBounds = node.bounds.inflate(toleranceWorld);
        if (hitBounds.contains(world)) {
          canvasFocusNode.requestFocus();
          final now = event.timeStamp;
          final isRepeatedClick = _lastTextPointerDownAt != null &&
              (now - _lastTextPointerDownAt!) <= _kDoubleClickTimeout &&
              _lastTextPointerDownLocal != null &&
              (event.localPosition - _lastTextPointerDownLocal!).distance <=
                  _kDoubleClickMaxDistance;
          controller.text.selectAtViewportOffset(
            event.localPosition,
            shiftExtend: HardwareKeyboard.instance.isShiftPressed,
            isRepeatedClick: isRepeatedClick,
            camera: controller.camera,
            pointer: event.pointer,
          );
          _textDragPointer = event.pointer;
          _lastTextPointerDownAt = now;
          _lastTextPointerDownLocal = event.localPosition;
          return;
        }
      }
      _textDragPointer = null;
      stopEditing(controller, commit: true);
    }

    if (tool.value == CanvasTool.select) {
      // On pointer-down in select mode, snapshot the pivots of every frame
      // so we can compute their delta on the next move events.
      if (event is PointerDownEvent) {
        _refreshFramePivotSnapshots(controller);
      }
      selectGestures.handlePointerEvent(event, controller);
      if (event is PointerMoveEvent) {
        _propagateFrameChildMotionInRuntime(controller);
      }
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _commitSelectInteractionToDocument(controller);
      }
      return;
    }

    final cam = controller.camera;
    if (event is PointerDownEvent) {
      if ((event.buttons & _kPrimaryMouseButton) == 0 ||
          (event.buttons & kMiddleMouseButton) != 0) {
        selectGestures.handlePointerEvent(event, controller);
        return;
      }
      _placePointer = event.pointer;
      _placeWorldStart = cam.localToGlobal(
        event.localPosition.dx,
        event.localPosition.dy,
      );
      _placeTool = tool.value;
      _placeQuadId = null;
      final start = _placeWorldStart!;
      _beginPreviewNode(controller, start, _placeTool!);
      return;
    }

    if (_placePointer == null) {
      selectGestures.handlePointerEvent(event, controller);
      return;
    }

    if (event.pointer != _placePointer) {
      selectGestures.handlePointerEvent(event, controller);
      return;
    }

    if (event is PointerMoveEvent) {
      final start = _placeWorldStart;
      if (start != null && _placeQuadId != null) {
        final cur = cam.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        _applyPreviewGeometry(controller, start, cur, lineFinalize: false);
      } else if (start != null && _placeTool == CanvasTool.text) {
        controller.invalidate();
      }
      return;
    }

    if (event is PointerUpEvent) {
      final start = _placeWorldStart;
      if (start != null) {
        final upWorld = cam.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        _finalizePlacement(controller, start, upWorld);
      }
      _clearPlacement();
      return;
    }

    if (event is PointerCancelEvent) {
      final id = _placeQuadId;
      if (id != null) {
        controller.node.remove(id);
      }
      _clearPlacement();
      return;
    }
  }

  void _refreshFramePivotSnapshots(InfiniteCanvasController controller) {
    _framePivotByNodeId.clear();
    for (final (frameQuadId, frameNode) in _orderedFrames(controller)) {
      final frameNodeId = _nodeIdForQuadId(frameQuadId);
      if (frameNodeId != null) {
        _framePivotByNodeId[frameNodeId] = frameNode.transformPivot;
      }
    }
  }

  bool handleKeyEvent(KeyEvent event, InfiniteCanvasController controller) {
    if (controller.text.editingQuadId != null) {
      if (!canvasFocusNode.hasFocus) {
        canvasFocusNode.requestFocus();
      }
      if (controller.text.handleKeyEvent(event, HardwareKeyboard.instance)) {
        return true;
      }
      return false;
    }

    if (event is KeyDownEvent) {
      final nextTool = toolForKeyEvent(event);
      if (nextTool != null) {
        final activator = onToolActivated;
        if (activator != null) {
          activator(nextTool);
        } else {
          tool.value = nextTool;
        }
        canvasFocusNode.requestFocus();
        return true;
      }
    }

    if (tool.value == CanvasTool.select) {
      return selectGestures.handleKeyEvent(event, controller);
    }
    return false;
  }
}
