import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'canvas_tool.dart';
import 'circle_node.dart';
import 'line_node.dart';
import 'rect_node.dart';
import 'text_node.dart';
import 'triangle_node.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

const int _kPrimaryMouseButton = 0x01;

/// Forwards to [DefaultInfiniteCanvasGestureHandler] in [CanvasTool.select];
/// in other tools, primary pointer creates nodes (drag or tap).
class DesignerGestureHandler extends InfiniteCanvasGestureHandler {
  DesignerGestureHandler({
    required this.tool,
    required this.delegate,
    required this.gestureConfig,
  });

  final ValueListenable<CanvasTool> tool;
  final DefaultInfiniteCanvasGestureHandler delegate;
  final InfiniteCanvasGestureConfig gestureConfig;

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
            color: const ui.Color(0xFFE65100),
            cornerRadiusWorld: 6,
            zIndex: 2,
          ),
        );
      case CanvasTool.circle:
        _placeQuadId = controller.addNode(
          CircleNode(
            center: start,
            radius: eps / 2,
            color: const ui.Color(0xFF7B1FA2),
            zIndex: 2,
          ),
        );
      case CanvasTool.triangle:
        _placeQuadId = controller.addNode(
          TriangleNode(
            center: start,
            side: eps,
            color: const ui.Color(0xFF00897B),
            zIndex: 2,
          ),
        );
      case CanvasTool.line:
        _placeQuadId = controller.addNode(
          LineNode(
            start: start,
            end: ui.Offset(start.dx + eps, start.dy),
            color: const ui.Color(0xFFC62828),
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
        controller.addNode(
          TextNode(
            position: start,
            text: 'Text',
            fontSizeWorld: 22,
            color: const ui.Color(0xFF37474F),
            zIndex: 2,
          ),
        );
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
      controller.requestRepaint();
      return;
    }

    if (_previewBelowMinSize(controller, start, end)) {
      controller.removeNode(id);
    } else {
      _applyPreviewGeometry(controller, start, end, lineFinalize: false);
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
    if (tool.value == CanvasTool.select) {
      return delegate.handleKeyEvent(event, controller);
    }
    return false;
  }
}
