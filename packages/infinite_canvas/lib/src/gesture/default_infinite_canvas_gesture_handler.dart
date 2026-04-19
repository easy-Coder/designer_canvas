import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller/infinite_canvas_controller.dart';
import 'infinite_canvas_gesture_config.dart';
import 'infinite_canvas_gesture_handler.dart';

/// Default pan, pinch, scroll zoom, trackpad pan/zoom, and optional keyboard shortcuts.
///
/// Pointer state lives on this instance (fed from [handlePointerEvent]).
class DefaultInfiniteCanvasGestureHandler extends InfiniteCanvasGestureHandler {
  DefaultInfiniteCanvasGestureHandler({
    this.config = const InfiniteCanvasGestureConfig(),
  });

  final InfiniteCanvasGestureConfig config;

  final Map<int, Offset> _pointers = HashMap();
  double? _pinchStartZoom;
  double? _pinchStartSpan;

  @override
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    if (event is PointerPanZoomUpdateEvent) {
      _handlePanZoomUpdate(event, controller);
      return;
    }
    if (event is PointerScrollEvent) {
      _onScroll(event, controller);
      return;
    }

    switch (event) {
      case PointerDownEvent e:
        _onDown(e, controller);
      case PointerMoveEvent e:
        _onMove(e, controller);
      case PointerUpEvent e:
        _onUp(e);
      case PointerCancelEvent e:
        _onCancel(e);
      default:
        break;
    }
  }

  void _handlePanZoomUpdate(
    PointerPanZoomUpdateEvent e,
    InfiniteCanvasController controller,
  ) {
    final cam = controller.camera;
    if (config.enablePan && e.panDelta != Offset.zero) {
      final z = cam.zoomDouble;
      if (z > 0) {
        cam.moveTo(
          cam.position -
              Offset(e.panDelta.dx / z, e.panDelta.dy / z),
        );
      }
    }
    if (config.enablePinchZoom && e.scale != 1.0) {
      final z0 = cam.zoomDouble;
      final z1 = (z0 * e.scale).clamp(cam.minZoom, cam.maxZoom);
      if (z1 != z0) {
        _applyZoomTowardsFocal(controller, z1, e.localPosition);
      }
    }
  }

  void _onDown(PointerDownEvent e, InfiniteCanvasController controller) {
    _pointers[e.pointer] = e.localPosition;
    if (config.enablePinchZoom && _pointers.length == 2) {
      _pinchStartZoom = controller.camera.zoomDouble;
      _pinchStartSpan = _span(_pointers.values.toList());
    }
    if (_pointers.length != 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }
  }

  void _onMove(PointerMoveEvent e, InfiniteCanvasController controller) {
    if (!_pointers.containsKey(e.pointer)) return;
    final prev = _pointers[e.pointer]!;
    _pointers[e.pointer] = e.localPosition;
    final delta = e.localPosition - prev;

    if (config.enablePan &&
        config.enablePinchZoom &&
        _pointers.length == 2 &&
        _pinchStartZoom != null &&
        _pinchStartSpan != null &&
        _pinchStartSpan! > 0) {
      final pts = _pointers.values.toList();
      final span = _span(pts);
      final z0 = _pinchStartZoom!;
      final scale = span / _pinchStartSpan!;
      final z1 = (z0 * scale).clamp(
        controller.camera.minZoom,
        controller.camera.maxZoom,
      );
      final focal = _centroid(pts);
      _applyZoomTowardsFocal(controller, z1, focal);
      return;
    }

    if (config.enablePan && _pointers.length == 1) {
      final z = controller.camera.zoomDouble;
      if (z <= 0) return;
      final worldDelta = Offset(delta.dx / z, delta.dy / z);
      controller.camera.moveTo(controller.camera.position - worldDelta);
    }
  }

  void _onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }
  }

  void _onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }
  }

  void _onScroll(PointerScrollEvent e, InfiniteCanvasController controller) {
    if (!config.enableScrollZoom) return;
    final dy = e.scrollDelta.dy;
    if (dy == 0) return;
    final sens = config.scrollZoomSensitivity;
    final factor = 1 + (dy > 0 ? -sens : sens);
    final cam = controller.camera;
    final z0 = cam.zoomDouble;
    final z1 = (z0 * factor).clamp(cam.minZoom, cam.maxZoom);
    if (z1 == z0) return;
    _applyZoomTowardsFocal(controller, z1, e.localPosition);
  }

  void _applyZoomTowardsFocal(
    InfiniteCanvasController controller,
    double newZoom,
    Offset focalLocal,
  ) {
    final cam = controller.camera;
    final worldBefore = cam.localToGlobal(focalLocal.dx, focalLocal.dy);
    cam.setZoomDouble(newZoom);
    final worldAfter = cam.localToGlobal(focalLocal.dx, focalLocal.dy);
    cam.moveTo(cam.position + (worldBefore - worldAfter));
  }

  @override
  bool handleKeyEvent(
    KeyEvent event,
    InfiniteCanvasController controller,
  ) {
    if (!config.enableKeyboardShortcuts) return false;
    if (event.deviceType != ui.KeyEventDeviceType.keyboard) return false;
    if (event is! KeyDownEvent) return false;

    final cam = controller.camera;
    final step = config.keyboardPanStepWorld;
    final dz = config.keyboardZoomStep;

    if (config.enablePan) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.arrowLeft) {
        return cam.moveTo(Offset(cam.position.dx - step, cam.position.dy));
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        return cam.moveTo(Offset(cam.position.dx + step, cam.position.dy));
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        return cam.moveTo(Offset(cam.position.dx, cam.position.dy - step));
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        return cam.moveTo(Offset(cam.position.dx, cam.position.dy + step));
      }
      if (k == LogicalKeyboardKey.keyW) {
        return cam.moveTo(Offset(cam.position.dx, cam.position.dy - step));
      }
      if (k == LogicalKeyboardKey.keyA) {
        return cam.moveTo(Offset(cam.position.dx - step, cam.position.dy));
      }
      if (k == LogicalKeyboardKey.keyS) {
        return cam.moveTo(Offset(cam.position.dx, cam.position.dy + step));
      }
      if (k == LogicalKeyboardKey.keyD) {
        return cam.moveTo(Offset(cam.position.dx + step, cam.position.dy));
      }
    }

    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.numpadAdd) {
      final z = (cam.zoomDouble + dz).clamp(cam.minZoom, cam.maxZoom);
      return cam.setZoomDouble(z);
    }
    if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      final z = (cam.zoomDouble - dz).clamp(cam.minZoom, cam.maxZoom);
      return cam.setZoomDouble(z);
    }
    return false;
  }

  static double _span(List<Offset> pts) {
    if (pts.length < 2) return 0;
    return (pts[0] - pts[1]).distance;
  }

  static Offset _centroid(List<Offset> pts) {
    if (pts.isEmpty) return Offset.zero;
    var s = Offset.zero;
    for (final p in pts) {
      s += p;
    }
    return s / pts.length.toDouble();
  }
}
