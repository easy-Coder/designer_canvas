import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../camera/camera.dart';
import '../controller/infinite_canvas_controller.dart';
import '../gesture/infinite_canvas_gesture_handler.dart';
import '../node/canvas_paint_context.dart';
import '../selection/selection_handles.dart';

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
    camera.changeSize(
      ui.Size(size.width, size.height),
      notify: false,
    );

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

    _paintSelectionOverlay(canvas, camera);

    canvas.restore();
  }

  void _paintSelectionOverlay(ui.Canvas canvas, Camera camera) {
    final zoom = camera.zoomDouble;

    const outlineWorld = 1.0;
    const dashWorld = 8.0;
    const gapWorld = 5.0;

    final marquee = controller.marqueeWorldRect;
    if (marquee != null) {
      final vr = camera.globalToLocalRect(marquee);
      final fill = ui.Paint()
        ..color = const ui.Color(0x402196F3)
        ..style = ui.PaintingStyle.fill;
      final stroke = ui.Paint()
        ..color = const ui.Color(0xFF2196F3)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = (outlineWorld * zoom).clamp(0.5, 6.0);
      canvas.drawRect(vr, fill);
      canvas.drawRect(vr, stroke);
    }

    final selStroke = ui.Paint()
      ..color = const ui.Color(0xFF2196F3)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = (1.5 * zoom).clamp(0.5, 6.0);

    for (final id in controller.selectedQuadIds) {
      final n = controller.lookupNode(id);
      if (n == null) continue;
      final vr = camera.globalToLocalRect(n.bounds);
      _paintDashedRect(
        canvas,
        vr,
        selStroke,
        zoom: zoom,
        dashWorld: dashWorld,
        gapWorld: gapWorld,
      );
    }

    final union = controller.selectedUnionBounds;
    if (union != null) {
      final vr = camera.globalToLocalRect(union);
      final boxPaint = ui.Paint()
        ..color = const ui.Color(0x00FFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = (2.0 * zoom).clamp(0.5, 8.0);
      final knobFill = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
      final knobStroke = ui.Paint()
        ..color = const ui.Color(0xFF1565C0)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = (1.0 * zoom).clamp(0.5, 4.0);
      SelectionHandles.paint(
        canvas: canvas,
        viewportRect: vr,
        zoom: zoom,
        boxPaint: boxPaint,
        knobFill: knobFill,
        knobStroke: knobStroke,
      );
    }
  }

  /// Dashed stroke along [rect] in viewport space; dash/gap lengths scale with
  /// [zoom] from world-space [dashWorld] / [gapWorld].
  static void _paintDashedRect(
    ui.Canvas canvas,
    ui.Rect rect,
    ui.Paint paint, {
    required double zoom,
    required double dashWorld,
    required double gapWorld,
  }) {
    final dash = dashWorld * zoom;
    final gap = gapWorld * zoom;

    void drawDashedLine(ui.Offset a, ui.Offset b) {
      final d = b - a;
      final len = d.distance;
      if (len < 1e-9) return;
      final dir = d / len;
      var t = 0.0;
      var drawDash = true;
      while (t < len) {
        final seg = math.min(drawDash ? dash : gap, len - t);
        if (drawDash) {
          final s = a + dir * t;
          final e = a + dir * (t + seg);
          canvas.drawLine(s, e, paint);
        }
        t += seg;
        drawDash = !drawDash;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }
}
