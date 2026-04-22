import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'canvas_tool.dart';
import 'circle_node.dart';
import 'line_node.dart';
import 'rect_node.dart';
import 'text_node.dart';
import 'tool_style_defaults.dart';
import 'triangle_node.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

const int _kPrimaryMouseButton = 0x01;

/// Forwards to [DefaultInfiniteCanvasGestureHandler] in [CanvasTool.select];
/// in other tools, primary pointer creates nodes (drag or tap).
class DesignerGestureHandler extends InfiniteCanvasGestureHandler {
  DesignerGestureHandler({
    required this.tool,
    required this.toolDefaults,
    required this.delegate,
    required this.gestureConfig,
  });

  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;
  final DefaultInfiniteCanvasGestureHandler delegate;
  final InfiniteCanvasGestureConfig gestureConfig;

  // ─── Text editing overlay state ──────────────────────────────────────
  /// Currently edited text node, or null.
  final ValueNotifier<({int quadId, TextNode node})?> _editingText =
      ValueNotifier(null);

  /// Start inline editing for [node] at [quadId].
  void startEditing(
    int quadId,
    TextNode node,
    InfiniteCanvasController controller,
  ) {
    // Stop any previous editing first.
    stopEditing(null);
    node.isEditing = true;
    _editingText.value = (quadId: quadId, node: node);
    controller.requestRepaint();
  }

  /// Commit current text (if [newText] non-null) and close the editor.
  void stopEditing(InfiniteCanvasController? controller) {
    final editing = _editingText.value;
    if (editing == null) return;
    editing.node.isEditing = false;
    _editingText.value = null;
    if (controller != null) {
      controller.updateNode(editing.quadId);
      controller.requestRepaint();
    }
  }

  // ─── Placement state ─────────────────────────────────────────────────
  int? _placePointer;
  ui.Offset? _placeWorldStart;
  CanvasTool? _placeTool;
  int? _placeQuadId;

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
      case CanvasTool.rect:
        final r = ui.Rect.fromCenter(center: start, width: eps, height: eps);
        _placeQuadId = controller.addNode(
          RectNode.fromAxisAlignedRect(
            r,
            style: toolDefaults.value.rect,
            zIndex: 2,
          ),
        );
      case CanvasTool.circle:
        _placeQuadId = controller.addNode(
          CircleNode(
            center: start,
            radius: eps / 2,
            style: toolDefaults.value.circle,
            zIndex: 2,
          ),
        );
      case CanvasTool.triangle:
        _placeQuadId = controller.addNode(
          TriangleNode(
            center: start,
            side: eps,
            style: toolDefaults.value.triangle,
            zIndex: 2,
          ),
        );
      case CanvasTool.line:
        _placeQuadId = controller.addNode(
          LineNode(
            start: start,
            end: ui.Offset(start.dx + eps, start.dy),
            style: toolDefaults.value.line,
            zIndex: 2,
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
    final node = controller.lookupNode(id);
    if (node == null) return;

    switch (t) {
      case CanvasTool.select:
      case CanvasTool.text:
        break;
      case CanvasTool.rect:
        (node as RectNode).setAxisAlignedWorldRect(_normalizeWorldRect(start, end));
        controller.updateNode(id);
      case CanvasTool.circle:
        final r = _normalizeWorldRect(start, end);
        final radius = math.min(r.width, r.height) / 2;
        (node as CircleNode).setCenterAndRadius(r.center, radius);
        controller.updateNode(id);
      case CanvasTool.triangle:
        final r = _normalizeWorldRect(start, end);
        final side = math.min(r.width, r.height);
        (node as TriangleNode).setCenterAndSide(r.center, side);
        controller.updateNode(id);
      case CanvasTool.line:
        var a = start;
        var b = end;
        if (lineFinalize && (b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        (node as LineNode).setWorldEndpoints(a, b);
        controller.updateNode(id);
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
      case CanvasTool.circle:
      case CanvasTool.triangle:
        final r = _normalizeWorldRect(start, end);
        return r.width < minW || r.height < minW;
      case CanvasTool.select:
      case CanvasTool.text:
      case CanvasTool.line:
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
        final newId = controller.addNode(
          TextNode(
            position: start,
            text: 'Text',
            style: toolDefaults.value.text,
            zIndex: 2,
          ),
        );
        controller.selectSingle(newId);
        final node = controller.lookupNode(newId);
        if (node is TextNode) {
          startEditing(newId, node, controller);
        }
        _switchToSelectTool();
      }
      controller.requestRepaint();
      return;
    }

    if (id == null || t == null || t == CanvasTool.select) {
      controller.requestRepaint();
      return;
    }

    if (t == CanvasTool.line) {
      _applyPreviewGeometry(controller, start, end, lineFinalize: true);
      controller.selectSingle(id);
      _switchToSelectTool();
      controller.requestRepaint();
      return;
    }

    if (_previewBelowMinSize(controller, start, end)) {
      controller.removeNode(id);
    } else {
      _applyPreviewGeometry(controller, start, end, lineFinalize: false);
      controller.selectSingle(id);
      _switchToSelectTool();
    }
    controller.requestRepaint();
  }

  @override
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    if (event is PointerScrollEvent ||
        event is PointerPanZoomUpdateEvent) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    if (tool.value != CanvasTool.select) {
      controller.clearHover();
    }

    // Dismiss the text editor when the user clicks anywhere (in any mode).
    if (event is PointerDownEvent && _editingText.value != null) {
      stopEditing(controller);
    }

    if (tool.value == CanvasTool.select) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    final cam = controller.camera;
    if (event is PointerDownEvent) {
      if ((event.buttons & _kPrimaryMouseButton) == 0 ||
          (event.buttons & kMiddleMouseButton) != 0) {
        delegate.handlePointerEvent(event, controller);
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
      delegate.handlePointerEvent(event, controller);
      return;
    }

    if (event.pointer != _placePointer) {
      delegate.handlePointerEvent(event, controller);
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
        controller.requestRepaint();
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
        controller.removeNode(id);
      }
      _clearPlacement();
      return;
    }
  }

  @override
  bool handleKeyEvent(
    KeyEvent event,
    InfiniteCanvasController controller,
  ) {
    // While editing text, don't consume key events so the TextField gets them.
    if (_editingText.value != null) return false;
    if (tool.value == CanvasTool.select) {
      return delegate.handleKeyEvent(event, controller);
    }
    return false;
  }

  // ─── Overlay widget ──────────────────────────────────────────────────
  @override
  Widget wrap(
    BuildContext context,
    InfiniteCanvasController controller,
    Widget child,
  ) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<({int quadId, TextNode node})?>( 
          valueListenable: _editingText,
          builder: (context, editing, _) {
            if (editing == null) return const SizedBox.shrink();
            return _TextEditOverlay(
              key: ValueKey(editing.quadId),
              node: editing.node,
              quadId: editing.quadId,
              camera: controller.camera,
              onDone: (newText) {
                editing.node.updateText(newText);
                stopEditing(controller);
              },
            );
          },
        ),
      ],
    );
  }
}

/// Positioned [TextField] over a [TextNode] in viewport space.
class _TextEditOverlay extends StatefulWidget {
  const _TextEditOverlay({
    super.key,
    required this.node,
    required this.quadId,
    required this.camera,
    required this.onDone,
  });

  final TextNode node;
  final int quadId;
  final Camera camera;
  final ValueChanged<String> onDone;

  @override
  State<_TextEditOverlay> createState() => _TextEditOverlayState();
}

class _TextEditOverlayState extends State<_TextEditOverlay> {
  late final TextEditingController _textCtrl;
  late final FocusNode _focus;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.node.text);
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
    // Auto-focus on next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _textCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _textCtrl.text.length,
        );
      }
    });
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && !_committed) {
      _commit();
    }
  }

  void _commit() {
    if (_committed) return;
    _committed = true;
    widget.onDone(_textCtrl.text);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.camera;
    final worldBounds = widget.node.bounds;
    final viewRect = cam.globalToLocalRect(worldBounds);

    final fontSize = widget.node.fontSizeWorld * cam.zoomDouble;

    return Positioned(
      left: viewRect.left,
      top: viewRect.top,
      width: viewRect.width,
      height: viewRect.height,
      child: EditableText(
        controller: _textCtrl,
        focusNode: _focus,
        style: TextStyle(
          color: Color(widget.node.color.toARGB32()),
          fontSize: fontSize,
          height: 1.0,
        ),
        cursorColor: Color(widget.node.color.toARGB32()),
        backgroundCursorColor: Colors.grey,
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
