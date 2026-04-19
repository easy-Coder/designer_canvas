import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../controller/infinite_canvas_controller.dart';
import '../node/canvas_paint_context.dart';

/// [RePainter] for [InfiniteCanvasController] scene graph.
///
/// Repaints when [InfiniteCanvasController] notifies. Pointer input is
/// expected from an outer [InfiniteCanvasGestureHandler] wrapper; this
/// painter’s [onPointerEvent] is a no-op by default.
class InfiniteCanvasRepainter implements RePainter {
  InfiniteCanvasRepainter(this.controller);

  final InfiniteCanvasController controller;

  RePaintBox? _box;
  bool _dirty = true;

  void _onController() {
    _dirty = true;
    _box?.markNeedsPaint();
  }

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    _box = box;
    controller.addListener(_onController);
  }

  @override
  void unmount() {
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
  void onPointerEvent(PointerEvent event) {}

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
