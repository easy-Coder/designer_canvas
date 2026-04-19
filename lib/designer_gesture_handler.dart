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

  void _finishPlacement(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
  ) {
    final minW = _minWorldSize(controller);
    final slop = _slopWorld(controller);

    switch (tool.value) {
      case CanvasTool.select:
        break;
      case CanvasTool.rect:
        final r = _normalizeWorldRect(start, end);
        if (r.width >= minW && r.height >= minW) {
          controller.addNode(
            RectNode.fromAxisAlignedRect(
              r,
              color: const ui.Color(0xFFE65100),
              cornerRadiusWorld: 6,
              zIndex: 2,
            ),
          );
        }
      case CanvasTool.circle:
        final r = _normalizeWorldRect(start, end);
        if (r.width >= minW && r.height >= minW) {
          final radius = math.min(r.width, r.height) / 2;
          controller.addNode(
            CircleNode(
              center: r.center,
              radius: radius,
              color: const ui.Color(0xFF7B1FA2),
              zIndex: 2,
            ),
          );
        }
      case CanvasTool.triangle:
        final r = _normalizeWorldRect(start, end);
        if (r.width >= minW && r.height >= minW) {
          final side = math.min(r.width, r.height);
          controller.addNode(
            TriangleNode(
              center: r.center,
              side: side,
              color: const ui.Color(0xFF00897B),
              zIndex: 2,
            ),
          );
        }
      case CanvasTool.line:
        var a = start;
        var b = end;
        if ((b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        controller.addNode(
          LineNode(
            start: a,
            end: b,
            color: const ui.Color(0xFFC62828),
            zIndex: 2,
          ),
        );
      case CanvasTool.text:
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
      controller.requestRepaint();
      return;
    }

    if (event is PointerUpEvent) {
      final start = _placeWorldStart;
      if (start != null) {
        final upWorld = cam.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        _finishPlacement(controller, start, upWorld);
      }
      _placePointer = null;
      _placeWorldStart = null;
      return;
    }

    if (event is PointerCancelEvent) {
      _placePointer = null;
      _placeWorldStart = null;
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
