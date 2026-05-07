import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../camera/camera.dart';
import '../controller/infinite_canvas_controller.dart';
import '../node/canvas_paint_context.dart';
import '../selection/selection_handles.dart';

/// [RePainter] for [InfiniteCanvasController] scene graph.
///
/// Pointer delivery is app-controlled: set [pointerCallback] from [InfiniteCanvasView].
/// Keyboard handling is app-controlled (e.g. wrap the view in [Focus]).
class InfiniteCanvasRepainter implements RePainter {
  InfiniteCanvasRepainter(this.controller);

  final InfiniteCanvasController controller;

  /// Called for each pointer event from the [RePaint] box when non-null.
  void Function(PointerEvent event)? pointerCallback;

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
  void onPointerEvent(PointerEvent event) {
    pointerCallback?.call(event);
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
    final activeEditingId = controller.text.editingQuadId;

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

    final hoverId = controller.hoveredQuadId;
    if (hoverId != null &&
        !controller.selectedQuadIds.contains(hoverId)) {
      final hoverNode = controller.lookupNode(hoverId);
      if (hoverNode != null) {
        final vr = camera.globalToLocalRect(hoverNode.bounds);
        final hoverStroke = ui.Paint()
          ..color = const ui.Color(0xFFFF8F00)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = (1.0 * zoom).clamp(0.5, 4.0);
        _paintDashedRect(
          canvas,
          vr,
          hoverStroke,
          zoom: zoom,
          dashWorld: dashWorld,
          gapWorld: gapWorld,
        );
      }
    }

    final selStroke = ui.Paint()
      ..color = const ui.Color(0xFF2196F3)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = (1.5 * zoom).clamp(0.5, 6.0);

    for (final id in controller.selectedQuadIds) {
      if (activeEditingId != null && id == activeEditingId) {
        continue;
      }
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

    final editingNode = activeEditingId == null
        ? null
        : controller.lookupNode(activeEditingId);
    if (editingNode != null) {
      final vr = camera.globalToLocalRect(editingNode.bounds);
      final editingStroke = ui.Paint()
        ..color = const ui.Color(0xFF42A5F5)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = (2.0 * zoom).clamp(0.75, 6.0);
      canvas.drawRect(vr, editingStroke);
    }

    final union = controller.selectedUnionBounds;
    if (union != null && activeEditingId == null) {
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
