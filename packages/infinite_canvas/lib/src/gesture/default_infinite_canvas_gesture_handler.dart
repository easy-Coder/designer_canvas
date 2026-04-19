import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../controller/infinite_canvas_controller.dart';
import 'infinite_canvas_gesture_config.dart';
import 'infinite_canvas_gesture_handler.dart';

/// Default pan (one pointer), pinch zoom, and scroll-wheel zoom.
///
/// Subclass to override hooks, or implement [InfiniteCanvasGestureHandler]
/// and delegate to an instance of this class for “default + custom” behavior.
class DefaultInfiniteCanvasGestureHandler extends InfiniteCanvasGestureHandler {
  DefaultInfiniteCanvasGestureHandler({
    this.config = const InfiniteCanvasGestureConfig(),
  });

  final InfiniteCanvasGestureConfig config;

  @override
  Widget wrap(
    BuildContext context,
    InfiniteCanvasController controller,
    Widget child,
  ) {
    return _GestureHost(
      controller: controller,
      config: config,
      child: child,
    );
  }
}

class _GestureHost extends StatefulWidget {
  const _GestureHost({
    required this.controller,
    required this.config,
    required this.child,
  });

  final InfiniteCanvasController controller;
  final InfiniteCanvasGestureConfig config;
  final Widget child;

  @override
  State<_GestureHost> createState() => _GestureHostState();
}

class _GestureHostState extends State<_GestureHost> {
  final Map<int, Offset> _pointers = HashMap();
  double? _pinchStartZoom;
  double? _pinchStartSpan;

  InfiniteCanvasController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            onPointerSignal: _onSignal,
          ),
        ),
      ],
    );
  }

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (widget.config.enablePinchZoom && _pointers.length == 2) {
      _pinchStartZoom = _c.camera.zoomDouble;
      _pinchStartSpan = _span(_pointers.values.toList());
    }
    if (_pointers.length != 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    final prev = _pointers[e.pointer]!;
    _pointers[e.pointer] = e.localPosition;
    final delta = e.localPosition - prev;

    if (widget.config.enablePan &&
        widget.config.enablePinchZoom &&
        _pointers.length == 2 &&
        _pinchStartZoom != null &&
        _pinchStartSpan != null &&
        _pinchStartSpan! > 0) {
      final pts = _pointers.values.toList();
      final span = _span(pts);
      final z0 = _pinchStartZoom!;
      final scale = span / _pinchStartSpan!;
      final z1 = (z0 * scale).clamp(_c.camera.minZoom, _c.camera.maxZoom);
      final focal = _centroid(pts);
      _applyZoomTowardsFocal(z1, focal);
      return;
    }

    if (widget.config.enablePan && _pointers.length == 1) {
      final z = _c.camera.zoomDouble;
      if (z <= 0) return;
      final worldDelta = Offset(delta.dx / z, delta.dy / z);
      _c.camera.moveTo(_c.camera.position - worldDelta);
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

  void _onSignal(PointerSignalEvent e) {
    if (!widget.config.enableScrollZoom) return;
    if (e is! PointerScrollEvent) return;
    final dy = e.scrollDelta.dy;
    if (dy == 0) return;
    final sens = widget.config.scrollZoomSensitivity;
    final factor = 1 + (dy > 0 ? -sens : sens);
    final z0 = _c.camera.zoomDouble;
    final z1 = (z0 * factor).clamp(_c.camera.minZoom, _c.camera.maxZoom);
    if (z1 == z0) return;
    _applyZoomTowardsFocal(z1, e.localPosition);
  }

  void _applyZoomTowardsFocal(double newZoom, Offset focalLocal) {
    final cam = _c.camera;
    final worldBefore = cam.localToGlobal(focalLocal.dx, focalLocal.dy);
    cam.setZoomDouble(newZoom);
    final worldAfter = cam.localToGlobal(focalLocal.dx, focalLocal.dy);
    cam.moveTo(cam.position + (worldBefore - worldAfter));
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
