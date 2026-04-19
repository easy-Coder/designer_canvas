import 'dart:ui' as ui;

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
}

class _TestNode extends CanvasNode {
  _TestNode(this._bounds);

  final ui.Rect _bounds;

  @override
  ui.Rect get bounds => _bounds;

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {}
}
