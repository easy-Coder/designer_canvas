import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'fixtures/smoke_text_node.dart';
import 'fixtures/visual_rect_test_node.dart';

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
    test('node.hitTest same zIndex prefers higher quad id', () {
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      ctrl.camera.changeSize(const ui.Size(400, 300));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final first = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(0, 0, 100, 100),
        zIndex: 3,
      );
      final second = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(40, 40, 100, 100),
        zIndex: 3,
      );
      final idFirst = ctrl.node.add(first);
      final idSecond = ctrl.node.add(second);
      expect(idSecond > idFirst, isTrue);
      final hit = ctrl.node.hitTest(const ui.Offset(50, 50));
      expect(hit, idSecond);
    });

    test('node.hitTest prefers higher zIndex', () {
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      ctrl.camera.changeSize(const ui.Size(400, 300));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final low = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(0, 0, 100, 100),
        zIndex: 1,
      );
      final high = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(40, 40, 100, 100),
        zIndex: 5,
      );
      ctrl.node.add(low);
      ctrl.node.add(high);

      final hit = ctrl.node.hitTest(const ui.Offset(50, 50));
      expect(hit, isNotNull);
      expect(ctrl.node.lookup(hit!)?.zIndex, 5);
    });

    test('selection marquee replaces and additive union', () {
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      final a = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
        zIndex: 1,
      );
      final b = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(20, 0, 10, 10),
        zIndex: 3,
      );
      final idA = ctrl.node.add(a);
      final idB = ctrl.node.add(b);

      ctrl.selection.beginMarquee(const ui.Offset(-1, -1));
      ctrl.selection.updateMarquee(const ui.Offset(14, 14));
      ctrl.selection.endMarquee(additive: false);
      expect(ctrl.selection.ids, {idA});

      ctrl.selection.beginMarquee(const ui.Offset(15, -1));
      ctrl.selection.updateMarquee(const ui.Offset(30, 14));
      ctrl.selection.endMarquee(additive: true);
      expect(ctrl.selection.ids, {idA, idB});
      expect(ctrl.selection.primaryId, idB);
    });

    test('remapRectInsideUnion maps fractions', () {
      const oldU = ui.Rect.fromLTWH(0, 0, 100, 100);
      const newU = ui.Rect.fromLTWH(10, 20, 200, 50);
      const inner = ui.Rect.fromLTWH(10, 10, 20, 30);
      final out = remapRectInsideUnion(inner, oldU, newU);
      expect(out.left, 10 + 10 / 100 * 200);
      expect(out.top, 20 + 10 / 100 * 50);
      expect(out.width, 20 / 100 * 200);
      expect(out.height, 30 / 100 * 50);
    });

    test('selectedUnionBounds unions all selected node bounds', () {
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      final a = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
      );
      final b = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(20, 5, 10, 10),
      );
      final idA = ctrl.node.add(a);
      final idB = ctrl.node.add(b);
      ctrl.selection.setIds({idA, idB}, primary: idB);
      expect(
        ctrl.selection.unionBounds,
        ui.Rect.fromLTRB(0, 0, 30, 15),
      );
    });

    test('primary click selects top z-index node at point', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      ctrl.camera.changeSize(const ui.Size(400, 300));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final low = VisualRectTestNode(
        center: const ui.Offset(50, 50),
        width: 100,
        height: 100,
        zIndex: 1,
        color: const ui.Color(0xFF000000),
      );
      final high = VisualRectTestNode(
        center: const ui.Offset(50, 50),
        width: 60,
        height: 60,
        zIndex: 10,
        color: const ui.Color(0xFF000001),
      );
      final idLow = ctrl.node.add(low);
      final idHigh = ctrl.node.add(high);
      ctrl.selection.setIds({idLow}, primary: idLow);

      const worldPt = ui.Offset(50, 50);
      final hit = ctrl.node.hitTest(worldPt);
      expect(hit, idHigh);
      ctrl.selection.selectSingle(hit!);

      expect(ctrl.selection.primaryId, idHigh);
      expect(ctrl.selection.ids, {idHigh});
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
      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));

      ctrl.camera.changeSize(const ui.Size(1000, 1000));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final inside = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(-10, -10, 20, 20),
      );
      final far = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(4000, 4000, 10, 10),
      );

      ctrl.node.add(inside);
      ctrl.node.add(far);

      final visible = ctrl.queryVisible(inflate: 0);
      expect(visible.length, 1);
      expect(visible.first, inside);
    });
  });

  group('InfiniteCanvasRepainter input', () {
    test('onPointerEvent callback receives pointer events', () {
      final ctrl = InfiniteCanvasController();
      final repainter = InfiniteCanvasRepainter(ctrl);
      final recorder = <PointerEvent>[];
      repainter.pointerCallback = recorder.add;

      final down = PointerDownEvent(
        pointer: 1,
        position: const ui.Offset(10, 20),
      );
      repainter.onPointerEvent(down);

      expect(recorder, hasLength(1));
      expect(recorder.first, same(down));
    });
  });

  group('API smoke (namespaces)', () {
    test('node.translate, applyStyle, marquee, transform drag, text editing', () {
      TestWidgetsFlutterBinding.ensureInitialized();

      final ctrl = InfiniteCanvasController();
      ctrl.setWorldBounds(const ui.Rect.fromLTWH(-5000, -5000, 10000, 10000));
      ctrl.camera.changeSize(const ui.Size(800, 600));
      ctrl.camera.moveTo(ui.Offset.zero);
      ctrl.camera.setZoomDouble(1.0);

      final rect = VisualRectTestNode.fromAxisAlignedRect(
        const ui.Rect.fromLTWH(100, 100, 80, 60),
      );
      rect.style = const TintNodeStyle(ui.Color(0xFF111111));
      final rid = ctrl.node.add(rect);
      ctrl.selection.setIds({rid}, primary: rid);

      ctrl.node.translate({rid}, const ui.Offset(3, -2));
      expect(ctrl.node.lookup(rid)!.bounds.left, 103);
      expect(ctrl.node.lookup(rid)!.bounds.top, 98);

      final nApplied = ctrl.node.applyStyle<TintNodeStyle>(
        (s) => s.withTint(const ui.Color(0xFF222222)),
      );
      expect(nApplied, 1);
      expect((ctrl.node.lookup(rid)!.style as TintNodeStyle).tint, const ui.Color(0xFF222222));

      ctrl.selection.beginMarquee(const ui.Offset(90, 90));
      ctrl.selection.updateMarquee(const ui.Offset(200, 200));
      ctrl.selection.endMarquee(additive: false);
      expect(ctrl.selection.ids, {rid});

      final brWorld = ctrl.selection.unionBounds!.bottomRight;
      ctrl.transform.beginHandleDrag(
        SelectionHandleKind.bottomRight,
        pointerWorld: brWorld,
      );
      ctrl.transform.updateHandleDrag(
        pointerWorld: brWorld + const ui.Offset(20, 15),
      );
      ctrl.transform.end();
      expect(ctrl.node.lookup(rid)!.bounds.width >= 80, isTrue);

      final textNode = SmokeTextNode()..text = '';
      final tid = ctrl.node.add(textNode);
      ctrl.text.beginEditing(tid);
      expect(ctrl.text.editingQuadId, tid);
      ctrl.text.insertText('hi');
      expect(textNode.editingValue.text, 'hi');
      ctrl.text.toggleBold();
      expect(textNode.boldToggleCount, 1);
      ctrl.text.stopEditing(commit: true);

      ctrl.dispose();
    });
  });
}
