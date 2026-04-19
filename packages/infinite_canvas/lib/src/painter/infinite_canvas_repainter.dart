import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../controller/infinite_canvas_controller.dart';
import '../gesture/infinite_canvas_gesture_handler.dart';
import '../node/canvas_paint_context.dart';

/// [RePainter] for [InfiniteCanvasController] scene graph.
///
/// Pointers: [RePaintBox] calls [onPointerEvent], which forwards to
/// [gestureHandler.handlePointerEvent].
///
/// Keyboard: [mount] registers [HardwareKeyboard.instance.addHandler] and
/// [unmount] removes it; events go to [gestureHandler.handleKeyEvent].
class InfiniteCanvasRepainter implements RePainter {
  InfiniteCanvasRepainter(this.controller);

  final InfiniteCanvasController controller;

  /// Updated by [InfiniteCanvasView] each build before [RePaint] paints.
  InfiniteCanvasGestureHandler gestureHandler =
      const NoopInfiniteCanvasGestureHandler();

  RePaintBox? _box;
  bool _dirty = true;

  late final KeyEventCallback _hardwareKeyboardHandler = _onHardwareKey;

  bool _onHardwareKey(KeyEvent event) {
    return gestureHandler.handleKeyEvent(event, controller);
  }

  void _onController() {
    _dirty = true;
    _box?.markNeedsPaint();
  }

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    _box = box;
    controller.addListener(_onController);
    HardwareKeyboard.instance.addHandler(_hardwareKeyboardHandler);
  }

  @override
  void unmount() {
    HardwareKeyboard.instance.removeHandler(_hardwareKeyboardHandler);
    controller.removeListener(_onController);
    _box = null;
  }

  @override
  void lifecycle(AppLifecycleState state) {}

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {}

  @override
  bool get needsPaint => _dirty;

  @override
  void onPointerEvent(PointerEvent event) {
    gestureHandler.handlePointerEvent(event, controller);
  }

  @override
  void paint(RePaintBox box, PaintingContext context) {
    _dirty = false;
    final size = box.size;
    final camera = controller.camera;
    camera.changeSize(ui.Size(size.width, size.height));

    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(ui.Offset.zero & size);

    final nodes = controller.queryVisible();
    for (final node in nodes) {
      final paintCtx = CanvasPaintContext(camera: camera, node: node);
      canvas.save();
      try {
        node.draw(canvas, paintCtx);
      } finally {
        canvas.restore();
      }
    }
    canvas.restore();
  }
}
