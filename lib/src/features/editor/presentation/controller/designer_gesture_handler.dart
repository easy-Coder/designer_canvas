import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/document_ops.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_child_motion.dart';
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
import 'package:designer_canvas/src/features/editor/presentation/controller/document_reducer.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/pending_image_placement.dart';
import 'package:designer_canvas/src/features/editor/presentation/editor_toolbar_metadata.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_input_config.dart';
import 'canvas_select_gestures.dart';

const int _kPrimaryMouseButton = 0x01;
const Duration _kDoubleClickTimeout = Duration(milliseconds: 350);
const double _kDoubleClickMaxDistance = 8.0;

/// Routes pointer/keyboard input for the designer: select gestures from
/// [CanvasSelectGestures], tool placement, and delegates text editing to
/// [InfiniteCanvasController.text].
class DesignerGestureHandler {
  DesignerGestureHandler({
    required this.tool,
    required this.toolDefaults,
    required this.frameSizePreset,
    required this.documentState,
    required this.runtimeBridge,
    required this.documentReducer,
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
  final RuntimeIndexBridge runtimeBridge;
  final DocumentReducer documentReducer;
  final CanvasSelectGestures selectGestures;
  final DesignerCanvasInputConfig gestureConfig;
  final FocusNode canvasFocusNode;
  final ValueNotifier<PendingImagePlacement?> pendingImagePlacement;
  final void Function(CanvasTool tool)? onToolActivated;

  int? _textDragPointer;
  Duration? _lastTextPointerDownAt;
  ui.Offset? _lastTextPointerDownLocal;

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
  }

  // ─── Placement state ─────────────────────────────────────────────────
  int? _placePointer;
  ui.Offset? _placeWorldStart;
  CanvasTool? _placeTool;
  int? _placeQuadId;
  final Map<String, ui.Offset> _framePivotSnapshotByNodeId =
      <String, ui.Offset>{};

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

  /// World-space size for the initial preview quad so indexing stays valid.
  double _previewSeed(InfiniteCanvasController controller) =>
      (1 / controller.camera.zoomDouble).clamp(1e-6, 100.0);

  void _clearPlacement() {
    _placePointer = null;
    _placeWorldStart = null;
    _placeTool = null;
    _placeQuadId = null;
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

  String? _nodeIdForQuadId(int quadId) => runtimeBridge.nodeIdForQuadId(quadId);

  int? _quadIdForNodeId(String nodeId) => runtimeBridge.quadIdForNodeId(nodeId);

  void _detachChild(int childId) {
    final childNodeId = _nodeIdForQuadId(childId);
    if (childNodeId == null) return;
    if (documentState.parentOf(childNodeId) == null) return;
    documentReducer.dispatch(NodeReparented(nodeId: childNodeId));
  }

  bool _isDescendantFrame(int ancestorFrameId, int probeFrameId) {
    final ancestorNodeId = _nodeIdForQuadId(ancestorFrameId);
    final probeNodeId = _nodeIdForQuadId(probeFrameId);
    if (ancestorNodeId == null || probeNodeId == null) return false;
    return documentState.isDescendantOf(ancestorNodeId, probeNodeId);
  }

  bool _canAssignToFrame(int childId, int frameId) {
    if (childId == frameId) return false;
    final childNodeId = _nodeIdForQuadId(childId);
    final frameNodeId = _nodeIdForQuadId(frameId);
    if (childNodeId == null || frameNodeId == null) return false;
    final frameParentNodeId = documentState.parentOf(frameNodeId);
    final frameParentQuadId = frameParentNodeId == null
        ? null
        : _quadIdForNodeId(frameParentNodeId);
    if (frameParentQuadId == childId) return false;
    if (_isDescendantFrame(childId, frameId)) return false;
    return true;
  }

  int? _bestContainingFrame(
    InfiniteCanvasController controller,
    int childId,
    CanvasNode childNode,
  ) {
    int? bestId;
    double? bestArea;
    final childBounds = childNode.bounds;
    for (final (frameId, frameNode) in _orderedFrames(controller)) {
      if (!_canAssignToFrame(childId, frameId)) continue;
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

  void _assignChildToFrame(
    InfiniteCanvasController controller,
    int childId,
    int frameId,
  ) {
    final childNode = controller.node.lookup(childId);
    final frameNode = controller.node.lookup(frameId);
    if (childNode == null || frameNode is! FrameNode) return;
    final childNodeId = _nodeIdForQuadId(childId);
    final frameNodeId = _nodeIdForQuadId(frameId);
    if (childNodeId == null || frameNodeId == null) return;
    documentReducer.dispatch(
      NodeReparented(
        nodeId: childNodeId,
        parentId: frameNodeId,
        containment: NodeContainmentData(
          localPivotX:
              childNode.transformPivot.dx - frameNode.transformPivot.dx,
          localPivotY:
              childNode.transformPivot.dy - frameNode.transformPivot.dy,
        ),
      ),
    );
  }

  void _recomputeMembershipFor(
    InfiniteCanvasController controller,
    int nodeId,
  ) {
    final node = controller.node.lookup(nodeId);
    if (node == null) {
      _detachChild(nodeId);
      return;
    }
    final frameId = _bestContainingFrame(controller, nodeId, node);
    if (frameId == null) {
      _detachChild(nodeId);
      return;
    }
    final childNodeId = _nodeIdForQuadId(nodeId);
    final frameNodeId = _nodeIdForQuadId(frameId);
    if (childNodeId == null || frameNodeId == null) return;
    if (documentState.parentOf(childNodeId) == frameNodeId) {
      final frameNode = controller.node.lookup(frameId);
      if (frameNode != null) {
        documentReducer.dispatch(
          NodeReparented(
            nodeId: childNodeId,
            parentId: frameNodeId,
            containment: NodeContainmentData(
              localPivotX: node.transformPivot.dx - frameNode.transformPivot.dx,
              localPivotY: node.transformPivot.dy - frameNode.transformPivot.dy,
            ),
          ),
        );
      }
      return;
    }
    _assignChildToFrame(controller, nodeId, frameId);
  }

  void _dropStaleRelationships(InfiniteCanvasController controller) {
    final stale = runtimeBridge.staleNodeIdsFromController();
    for (final nodeId in stale) {
      documentReducer.dispatch(NodeDeleted(nodeId));
    }
    final snapshot = documentState.nodesById.values.toList(growable: false);
    for (final entity in snapshot) {
      final parentId = entity.parentId;
      if (parentId != null && !documentState.containsNode(parentId)) {
        documentReducer.dispatch(NodeReparented(nodeId: entity.id));
      }
    }
  }

  void _moveFrameChildren(InfiniteCanvasController controller) {
    propagateFrameChildMotion(
      controller: controller,
      documentState: documentState,
      runtimeBridge: runtimeBridge,
      framePivotSnapshotByNodeId: _framePivotSnapshotByNodeId,
    );
  }

  void _sweepFramePivotSnapshots(InfiniteCanvasController controller) {
    final activeFrameIds = <String>{};
    for (final (frameQuadId, _) in _orderedFrames(controller)) {
      final frameNodeId = _nodeIdForQuadId(frameQuadId);
      if (frameNodeId != null) {
        activeFrameIds.add(frameNodeId);
      }
    }
    final stale = _framePivotSnapshotByNodeId.keys
        .where((id) => !activeFrameIds.contains(id))
        .toList(growable: false);
    for (final id in stale) {
      _framePivotSnapshotByNodeId.remove(id);
    }
  }

  void _syncFrameGroupingAfterInteraction(
    InfiniteCanvasController controller, {
    bool recomputeMembership = false,
  }) {
    _dropStaleRelationships(controller);
    _moveFrameChildren(controller);
    _syncDocumentGeometryFromRuntime(controller);
    _sweepFramePivotSnapshots(controller);
    if (recomputeMembership) {
      for (final (nodeId, node) in controller.orderedNodes) {
        if (node is FrameNode) continue;
        _recomputeMembershipFor(controller, nodeId);
      }
      _dropStaleRelationships(controller);
    }
  }

  void _syncDocumentGeometryFromRuntime(InfiniteCanvasController controller) {
    var changed = false;
    final mapped = runtimeBridge.nodeIdByQuadId.entries.toList();
    for (final entry in mapped) {
      final quadId = entry.key;
      final nodeId = entry.value;
      final node = controller.node.lookup(quadId);
      if (node == null) continue;
      final current = documentState.nodeById(nodeId);
      final entity = runtimeBridge.nodeCodec.entityFromNode(
        node,
        nodeId: nodeId,
        parentId: current?.parentId,
        containment: current?.containment,
      );
      documentState.upsertNode(entity, notify: false);
      changed = true;
    }
    if (changed) {
      documentState.emitChange();
    }
  }

  int _commitRuntimeNodeCreation(
    InfiniteCanvasController controller,
    int quadId,
  ) {
    if (controller.node.lookup(quadId) == null) return quadId;
    final nodeId = runtimeBridge.nodeCodec.newNodeId();
    runtimeBridge.promoteRuntimeNodeAsEntity(quadId, nodeId: nodeId);
    return runtimeBridge.quadIdForNodeId(nodeId) ?? quadId;
  }

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
        final selectedImage = pendingImagePlacement.value;
        _placeQuadId = controller.node.add(
          ImageNode(
            center: start,
            width: eps,
            height: eps,
            style: toolDefaults.value.image,
            zIndex: 2,
            sourceFileName: selectedImage?.fileName,
            sourceFilePath: selectedImage?.filePath,
            intrinsicWidth: selectedImage?.intrinsicWidth,
            intrinsicHeight: selectedImage?.intrinsicHeight,
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
        final newId = controller.node.add(
          TextNode(
            position: start,
            text: 'Text',
            style: toolDefaults.value.text,
            zIndex: 2,
          ),
        );
        final runtimeQuadId = _commitRuntimeNodeCreation(controller, newId);
        controller.selection.selectSingle(runtimeQuadId);
        final node = controller.node.lookup(runtimeQuadId);
        if (node is TextNode) {
          startEditing(runtimeQuadId, node, controller);
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

    if (t == CanvasTool.line || t == CanvasTool.pen || t == CanvasTool.arrow) {
      _applyPreviewGeometry(controller, start, end, lineFinalize: true);
      final runtimeQuadId = _commitRuntimeNodeCreation(controller, id);
      controller.selection.selectSingle(runtimeQuadId);
      _switchToSelectTool();
      controller.invalidate();
      return;
    }

    if (t == CanvasTool.frame && (end - start).distance <= slop) {
      final runtimeQuadId = _commitRuntimeNodeCreation(controller, id);
      controller.selection.selectSingle(runtimeQuadId);
      _switchToSelectTool();
      controller.invalidate();
      return;
    }

    if (t == CanvasTool.image && (end - start).distance <= slop) {
      final selectedImage = pendingImagePlacement.value;
      if (selectedImage == null) {
        controller.node.remove(id);
        controller.invalidate();
        return;
      }
      final clickRect = ui.Rect.fromCenter(
        center: start,
        width: selectedImage.intrinsicWidth,
        height: selectedImage.intrinsicHeight,
      );
      final node = controller.node.lookup(id);
      if (node is ImageNode) {
        node.setAxisAlignedWorldRect(clickRect);
        node.setSource(
          fileName: selectedImage.fileName,
          filePath: selectedImage.filePath,
          intrinsicWidth: selectedImage.intrinsicWidth,
          intrinsicHeight: selectedImage.intrinsicHeight,
        );
        controller.node.reindex(id);
      }
      final runtimeQuadId = _commitRuntimeNodeCreation(controller, id);
      controller.selection.selectSingle(runtimeQuadId);
      _switchToSelectTool();
      controller.invalidate();
      return;
    }

    if (_previewBelowMinSize(controller, start, end)) {
      controller.node.remove(id);
    } else {
      _applyPreviewGeometry(controller, start, end, lineFinalize: false);
      final runtimeQuadId = _commitRuntimeNodeCreation(controller, id);
      controller.selection.selectSingle(runtimeQuadId);
      _switchToSelectTool();
    }
    controller.invalidate();
  }

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
          final isRepeatedClick =
              _lastTextPointerDownAt != null &&
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
      selectGestures.handlePointerEvent(event, controller);
      final shouldRecomputeMembership =
          event is PointerUpEvent || event is PointerCancelEvent;
      _syncFrameGroupingAfterInteraction(
        controller,
        recomputeMembership: shouldRecomputeMembership,
      );
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
        _syncFrameGroupingAfterInteraction(
          controller,
          recomputeMembership: true,
        );
      }
      _clearPlacement();
      return;
    }

    if (event is PointerCancelEvent) {
      final id = _placeQuadId;
      if (id != null) {
        controller.node.remove(id);
      }
      _syncFrameGroupingAfterInteraction(controller, recomputeMembership: true);
      _clearPlacement();
      return;
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
