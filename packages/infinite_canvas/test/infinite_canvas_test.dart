import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

void main() {
  group('Camera', () {
    test('globalToLocal / localToGlobal round-trip', () {
      final cam = Camera(
        viewportSize: const ui.Size(800, 600),
        position: const ui.Offset(100, 50),
        zoomDouble: 0.5,
      );

      const world = ui.Offset(40, -120);
      final local = cam.globalToLocal(world.dx, world.dy);
      final back = cam.localToGlobal(local.dx, local.dy);
      expect((back.dx - world.dx).abs() < 1e-6, isTrue);
      expect((back.dy - world.dy).abs() < 1e-6, isTrue);
    });

    test('round-trip at zoom 1', () {
      final cam = Camera(
        viewportSize: const ui.Size(400, 300),
        position: ui.Offset.zero,
        zoomDouble: 1.0,
      );
      const world = ui.Offset(12.5, 99);
      final local = cam.globalToLocal(world.dx, world.dy);
      final back = cam.localToGlobal(local.dx, local.dy);
      expect(back, world);
    });

    test('Rect round-trip', () {
      final cam = Camera(
        viewportSize: const ui.Size(500, 500),
        position: const ui.Offset(10, 20),
        zoomDouble: 0.25,
      );
      const r = ui.Rect.fromLTWH(5, 6, 30, 40);
      final local = cam.globalToLocalRect(r);
      final back = cam.localToGlobalRect(local);
      expect((back.left - r.left).abs() < 1e-5, isTrue);
      expect((back.top - r.top).abs() < 1e-5, isTrue);
      expect((back.width - r.width).abs() < 1e-5, isTrue);
      expect((back.height - r.height).abs() < 1e-5, isTrue);
    });
  });

  group('Selection + hit testing', () {
    test('pickTopNodeAtWorld prefers higher zIndex', () {
      const world = ui.Rect.fromLTWH(-5000, -5000, 10000, 10000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      ctrl.camera.changeSize(const ui.Size(400, 300));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final low = _TestNode(ui.Rect.fromLTWH(0, 0, 100, 100), zIndex: 1);
      final high = _TestNode(ui.Rect.fromLTWH(40, 40, 100, 100), zIndex: 5);
      ctrl.addNode(low);
      ctrl.addNode(high);

      final hit = ctrl.pickTopNodeAtWorld(const ui.Offset(50, 50));
      expect(hit, isNotNull);
      expect(ctrl.lookupNode(hit!)?.zIndex, 5);
    });

    test('applyMarquee replaces and additive union', () {
      const world = ui.Rect.fromLTWH(-5000, -5000, 10000, 10000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      final a = _TestNode(ui.Rect.fromLTWH(0, 0, 10, 10), zIndex: 1);
      final b = _TestNode(ui.Rect.fromLTWH(20, 0, 10, 10), zIndex: 3);
      final idA = ctrl.addNode(a);
      final idB = ctrl.addNode(b);

      ctrl.applyMarquee(ui.Rect.fromLTWH(-1, -1, 15, 15), additive: false);
      expect(ctrl.selectedQuadIds, {idA});

      ctrl.applyMarquee(ui.Rect.fromLTWH(15, -1, 15, 15), additive: true);
      expect(ctrl.selectedQuadIds, {idA, idB});
      expect(ctrl.primaryQuadId, idB);
    });

    test('selectedUnionBounds unions all selected node bounds', () {
      const world = ui.Rect.fromLTWH(-5000, -5000, 10000, 10000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      final a = _TestNode(ui.Rect.fromLTWH(0, 0, 10, 10));
      final b = _TestNode(ui.Rect.fromLTWH(20, 5, 10, 10));
      final idA = ctrl.addNode(a);
      final idB = ctrl.addNode(b);
      ctrl.setSelection({idA, idB}, primary: idB);
      expect(
        ctrl.selectedUnionBounds,
        ui.Rect.fromLTRB(0, 0, 30, 15),
      );
    });

    test('SelectionHandles.hitTest hits corner knob', () {
      const vr = ui.Rect.fromLTWH(100, 80, 200, 120);
      expect(
        SelectionHandles.hitTest(
          viewportRect: vr,
          local: const ui.Offset(100, 80),
          zoom: 1.0,
        ),
        SelectionHandleKind.topLeft,
      );
      expect(
        SelectionHandles.hitTest(
          viewportRect: vr,
          local: const ui.Offset(200, 60),
          zoom: 1.0,
        ),
        SelectionHandleKind.rotate,
      );
      expect(
        SelectionHandles.hitTest(
          viewportRect: vr,
          local: ui.Offset(vr.center.dx, vr.center.dy),
          zoom: 1.0,
        ),
        isNull,
      );
    });
  });

  group('InfiniteCanvasController + QuadTree', () {
    test('queryVisible returns nodes in inflated camera bound', () {
      const world = ui.Rect.fromLTWH(-5000, -5000, 10000, 10000);
      final ctrl = InfiniteCanvasController(worldBounds: world);

      ctrl.camera.changeSize(const ui.Size(1000, 1000));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final inside = _TestNode(ui.Rect.fromLTWH(-10, -10, 20, 20));
      final far = _TestNode(ui.Rect.fromLTWH(4000, 4000, 10, 10));

      ctrl.addNode(inside);
      ctrl.addNode(far);

      final visible = ctrl.queryVisible(inflate: 0);
      expect(visible.length, 1);
      expect(visible.first, inside);
    });
  });

  group('InfiniteCanvasRepainter input', () {
    test('onPointerEvent forwards to gestureHandler', () {
      const world = ui.Rect.fromLTWH(-1000, -1000, 2000, 2000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      final repainter = InfiniteCanvasRepainter(ctrl);
      final recorder = _RecordingGestureHandler();
      repainter.gestureHandler = recorder;

      final down = PointerDownEvent(
        pointer: 1,
        position: const ui.Offset(10, 20),
      );
      repainter.onPointerEvent(down);

      expect(recorder.pointerEvents, hasLength(1));
      expect(recorder.pointerEvents.first, same(down));
    });

    test('Default handler keyboard shortcuts when disabled', () {
      const world = ui.Rect.fromLTWH(-1000, -1000, 2000, 2000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      final h = DefaultInfiniteCanvasGestureHandler(
        config: const InfiniteCanvasGestureConfig(
          enableKeyboardShortcuts: false,
        ),
      );
      final ev = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
        deviceType: ui.KeyEventDeviceType.keyboard,
      );
      expect(h.handleKeyEvent(ev, ctrl), isFalse);
    });

    test('Default handler keyboard pan when enabled', () {
      const world = ui.Rect.fromLTWH(-1000, -1000, 2000, 2000);
      final ctrl = InfiniteCanvasController(worldBounds: world);
      ctrl.camera.moveTo(const ui.Offset(100, 100));
      final h = DefaultInfiniteCanvasGestureHandler(
        config: const InfiniteCanvasGestureConfig(
          enableKeyboardShortcuts: true,
          enablePan: true,
          keyboardPanStepWorld: 10,
        ),
      );
      final ev = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
        deviceType: ui.KeyEventDeviceType.keyboard,
      );
      expect(h.handleKeyEvent(ev, ctrl), isTrue);
      expect(ctrl.camera.position.dx, 90);
    });
  });
}

final class _RecordingGestureHandler extends InfiniteCanvasGestureHandler {
  _RecordingGestureHandler();

  final List<PointerEvent> pointerEvents = [];

  @override
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    pointerEvents.add(event);
  }
}

class _TestNode extends CanvasNode {
  _TestNode(this._bounds, {int zIndex = 0}) : _zIndex = zIndex;

  final ui.Rect _bounds;
  final int _zIndex;

  @override
  int get zIndex => _zIndex;

  @override
  ui.Rect get bounds => _bounds;

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {}
}
