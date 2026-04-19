import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller/infinite_canvas_controller.dart';
import '../selection/selection_handles.dart';
import '../util/transform_union_geometry.dart';
import 'infinite_canvas_gesture_config.dart';
import 'infinite_canvas_gesture_handler.dart';

/// Same value as Flutter's `kPrimaryMouseButton` (not exported on all channels).
const int _kPrimaryMouseButton = 0x01;

enum _PrimarySession {
  idle,
  downEmpty,
  downNode,
  marquee,
  handleTransform,
  nodeDrag,
}

/// Default gestures: selection / marquee / handles, wheel + MMB camera, pinch,
/// optional keyboard shortcuts.
///
/// **Primary hit order:** [InfiniteCanvasController.pickTopNodeAtWorld] runs
/// first so the top-most node by [CanvasNode.zIndex] (then quad id) wins.
/// Transform handles on the selection union run when a handle is hit and
/// either no node is under the pointer ([pickTopNodeAtWorld] is null, e.g.
/// rotate affordance above bounds) or the top hit is already selected. If an
/// unselected node is on top, it wins over handles. Primary down on an
/// unselected top node (without Shift) replaces the selection via
/// [InfiniteCanvasController.selectSingle].
class DefaultInfiniteCanvasGestureHandler extends InfiniteCanvasGestureHandler {
  DefaultInfiniteCanvasGestureHandler({
    this.config = const InfiniteCanvasGestureConfig(),
  });

  final InfiniteCanvasGestureConfig config;

  final Map<int, Offset> _pointers = HashMap();
  final Set<int> _middlePanPointers = {};
  double? _pinchStartZoom;
  double? _pinchStartSpan;

  int? _primaryPointer;
  _PrimarySession _primarySession = _PrimarySession.idle;
  Offset? _primaryDownLocal;
  ui.Offset? _marqueeAnchorWorld;
  int? _downQuadId;

  int? _lastTapQuadId;
  DateTime? _lastTapTime;
  Offset? _lastTapLocal;

  SelectionHandleKind? _activeHandle;
  bool _transformBaselinePrepared = false;
  ui.Rect? _transformStartUnion;
  Map<int, ui.Rect>? _boundsSnapshot;
  ui.Offset? _rotatePointerWorldLast;

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

    if (event is PointerHoverEvent) {
      _updateHover(event, controller);
      return;
    }
    if (event is PointerMoveEvent && event.buttons == 0) {
      _updateHover(event, controller);
    }

    switch (event) {
      case PointerDownEvent e:
        _onDown(e, controller);
      case PointerMoveEvent e:
        _onMove(e, controller);
      case PointerUpEvent e:
        _onUp(e, controller);
      case PointerCancelEvent e:
        _onCancel(e, controller);
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

  bool _isMiddle(PointerDownEvent e) =>
      (e.buttons & kMiddleMouseButton) != 0;

  void _onDown(PointerDownEvent e, InfiniteCanvasController controller) {
    _pointers[e.pointer] = e.localPosition;

    if (_isMiddle(e) && config.middleMousePan) {
      _middlePanPointers.add(e.pointer);
      return;
    }

    if (config.enablePinchZoom && _pointers.length == 2) {
      _pinchStartZoom = controller.camera.zoomDouble;
      _pinchStartSpan = _span(_pointers.values.toList());
      _cancelPrimarySession(controller);
    } else if (_pointers.length != 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }

    if ((e.buttons & _kPrimaryMouseButton) != 0 &&
        config.enableSelection &&
        !_middlePanPointers.contains(e.pointer)) {
      controller.clearHover();
      final cam = controller.camera;
      final world = cam.localToGlobal(e.localPosition.dx, e.localPosition.dy);

      final hitId = controller.pickTopNodeAtWorld(world);

      if (hitId != null &&
          !controller.selectedQuadIds.contains(hitId) &&
          !HardwareKeyboard.instance.isShiftPressed) {
        controller.selectSingle(hitId);
      }

      final union = controller.selectedUnionBounds;
      if (controller.selectedQuadIds.isNotEmpty && union != null) {
        final vr = cam.globalToLocalRect(union);
        final handle = SelectionHandles.hitTest(
          viewportRect: vr,
          local: e.localPosition,
          zoom: cam.zoomDouble,
        );
        final allowHandle = handle != null &&
            (hitId == null ||
                controller.selectedQuadIds.contains(hitId));
        if (allowHandle) {
          _primaryPointer = e.pointer;
          _primarySession = _PrimarySession.handleTransform;
          _primaryDownLocal = e.localPosition;
          _activeHandle = handle;
          _transformBaselinePrepared = false;
          _transformStartUnion = null;
          _boundsSnapshot = null;
          _rotatePointerWorldLast = null;
          return;
        }
      }

      _primaryPointer = e.pointer;
      _primaryDownLocal = e.localPosition;
      _downQuadId = hitId;
      if (hitId == null) {
        _primarySession = _PrimarySession.downEmpty;
        _marqueeAnchorWorld = world;
      } else {
        _primarySession = _PrimarySession.downNode;
      }
    }
  }

  void _cancelPrimarySession(InfiniteCanvasController controller) {
    _endTransformSessions(controller);
    _activeHandle = null;
    _transformBaselinePrepared = false;
    _transformStartUnion = null;
    _boundsSnapshot = null;
    _rotatePointerWorldLast = null;
    _primaryPointer = null;
    _primarySession = _PrimarySession.idle;
    _primaryDownLocal = null;
    _marqueeAnchorWorld = null;
    _downQuadId = null;
    controller.marqueeWorldRect = null;
  }

  void _endTransformSessions(InfiniteCanvasController controller) {
    for (final id in controller.selectedQuadIds) {
      controller.lookupNode(id)?.endTransformSession();
    }
  }

  void _prepareTransformBaseline(InfiniteCanvasController controller) {
    if (_transformBaselinePrepared) return;
    final union = controller.selectedUnionBounds;
    if (union == null) {
      _transformBaselinePrepared = true;
      return;
    }
    _transformBaselinePrepared = true;
    _transformStartUnion = union;
    _boundsSnapshot = {
      for (final id in controller.selectedQuadIds)
        id: controller.lookupNode(id)!.bounds,
    };
    if (_activeHandle != SelectionHandleKind.rotate) {
      for (final id in controller.selectedQuadIds) {
        controller.lookupNode(id)?.beginTransformSession();
      }
    }
  }

  void _onMove(PointerMoveEvent e, InfiniteCanvasController controller) {
    if (!_pointers.containsKey(e.pointer)) return;
    final prev = _pointers[e.pointer]!;
    _pointers[e.pointer] = e.localPosition;
    final delta = e.localPosition - prev;

    if (_middlePanPointers.contains(e.pointer) && config.middleMousePan) {
      final z = controller.camera.zoomDouble;
      if (z > 0) {
        controller.camera.moveTo(
          controller.camera.position -
              Offset(delta.dx / z, delta.dy / z),
        );
      }
      return;
    }

    if (config.enablePinchZoom &&
        config.enablePan &&
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

    if (config.enableSelection &&
        e.pointer == _primaryPointer &&
        _primarySession != _PrimarySession.idle) {
      final cam = controller.camera;
      final slop = config.selectionSlopPixels;
      final moved = (_primaryDownLocal! - e.localPosition).distance;

      switch (_primarySession) {
        case _PrimarySession.handleTransform:
          if (!config.enableNodeTransform) {
            controller.requestRepaint();
            return;
          }
          if (moved >= slop) {
            _prepareTransformBaseline(controller);
          }
          if (!_transformBaselinePrepared ||
              _transformStartUnion == null ||
              _boundsSnapshot == null ||
              _activeHandle == null) {
            controller.requestRepaint();
            return;
          }
          final pointerWorld = cam.localToGlobal(
            e.localPosition.dx,
            e.localPosition.dy,
          );
          if (_activeHandle == SelectionHandleKind.rotate) {
            final center = _transformStartUnion!.center;
            if (_rotatePointerWorldLast == null) {
              _rotatePointerWorldLast = pointerWorld;
              return;
            }
            final v0 = _rotatePointerWorldLast! - center;
            final v1 = pointerWorld - center;
            if (v0.distance > 1e-9 && v1.distance > 1e-9) {
              final cross = v0.dx * v1.dy - v0.dy * v1.dx;
              final dot = v0.dx * v1.dx + v0.dy * v1.dy;
              final delta = math.atan2(cross, dot);
              for (final id in controller.selectedQuadIds) {
                controller.lookupNode(id)?.rotateWorldAround(center, delta);
              }
              controller.relayoutNodes(controller.selectedQuadIds);
            }
            _rotatePointerWorldLast = pointerWorld;
            return;
          }
          final newUnion = unionForHandleDrag(
            kind: _activeHandle!,
            startUnion: _transformStartUnion!,
            pointerWorld: pointerWorld,
            minWidth: config.minUnionSizeWorld,
            minHeight: config.minUnionSizeWorld,
          );
          for (final id in controller.selectedQuadIds) {
            final snap = _boundsSnapshot![id];
            if (snap == null) continue;
            final n = controller.lookupNode(id);
            n?.remapBoundsInUnion(snap, _transformStartUnion!, newUnion);
          }
          controller.relayoutNodes(controller.selectedQuadIds);
          return;
        case _PrimarySession.nodeDrag:
          if (!config.enableNodeTransform) {
            controller.requestRepaint();
            return;
          }
          final z = cam.zoomDouble;
          if (z <= 0) return;
          final worldDelta = ui.Offset(delta.dx / z, delta.dy / z);
          final hit = _downQuadId;
          if (hit == null) return;
          final targets = controller.selectedQuadIds.contains(hit)
              ? controller.selectedQuadIds
              : <int>{hit};
          for (final id in targets) {
            controller.lookupNode(id)?.translateWorld(worldDelta);
          }
          controller.relayoutNodes(targets);
          return;
        case _PrimarySession.downEmpty:
          if (moved >= slop) {
            _primarySession = _PrimarySession.marquee;
            final a = _marqueeAnchorWorld!;
            final b = cam.localToGlobal(e.localPosition.dx, e.localPosition.dy);
            controller.marqueeWorldRect = _normalizeWorldRect(a, b);
          }
          return;
        case _PrimarySession.downNode:
          if (moved >= slop) {
            _primarySession = _PrimarySession.nodeDrag;
          }
          return;
        case _PrimarySession.marquee:
          final a = _marqueeAnchorWorld!;
          final b = cam.localToGlobal(e.localPosition.dx, e.localPosition.dy);
          controller.marqueeWorldRect = _normalizeWorldRect(a, b);
          return;
        case _PrimarySession.idle:
          break;
      }
    }

    if (!config.enableSelection &&
        config.enablePan &&
        _pointers.length == 1 &&
        !_middlePanPointers.contains(e.pointer)) {
      final z = controller.camera.zoomDouble;
      if (z <= 0) return;
      final worldDelta = Offset(delta.dx / z, delta.dy / z);
      controller.camera.moveTo(controller.camera.position - worldDelta);
    }
  }

  void _onUp(PointerUpEvent e, InfiniteCanvasController controller) {
    _middlePanPointers.remove(e.pointer);
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }

    if (config.enableSelection && e.pointer == _primaryPointer) {
      final slop = config.selectionSlopPixels;
      final moved = _primaryDownLocal != null
          ? (_primaryDownLocal! - e.localPosition).distance
          : 0.0;

      switch (_primarySession) {
        case _PrimarySession.handleTransform:
          controller.requestRepaint();
          break;
        case _PrimarySession.marquee:
          final rect = controller.marqueeWorldRect;
          if (rect != null && rect.width > 1e-6 && rect.height > 1e-6) {
            final additive = HardwareKeyboard.instance.isShiftPressed;
            controller.applyMarquee(rect, additive: additive);
          } else {
            controller.marqueeWorldRect = null;
          }
          break;
        case _PrimarySession.downEmpty:
          if (moved < slop) {
            controller.clearSelection();
          }
          break;
        case _PrimarySession.downNode:
          if (moved < slop && _downQuadId != null) {
            final id = _downQuadId!;
            final node = controller.lookupNode(id);
            final now = DateTime.now();
            if (HardwareKeyboard.instance.isShiftPressed) {
              controller.toggleInSelection(id);
              _lastTapQuadId = null;
              _lastTapTime = null;
              _lastTapLocal = null;
            } else {
              final mergeDist = config.selectionSlopPixels * 2;
              final closeEnough = _lastTapLocal != null &&
                  (e.localPosition - _lastTapLocal!).distance <= mergeDist;
              if (controller.onNodeDoubleClick != null &&
                  node != null &&
                  id == _lastTapQuadId &&
                  _lastTapTime != null &&
                  closeEnough &&
                  now.difference(_lastTapTime!) < config.doubleClickTimeout) {
                controller.onNodeDoubleClick!(id, node);
                _lastTapQuadId = null;
                _lastTapTime = null;
                _lastTapLocal = null;
              } else {
                controller.selectSingle(id);
                _lastTapQuadId = id;
                _lastTapTime = now;
                _lastTapLocal = e.localPosition;
              }
            }
          }
          break;
        case _PrimarySession.nodeDrag:
          controller.requestRepaint();
          break;
        case _PrimarySession.idle:
          break;
      }
      _cancelPrimarySession(controller);
      return;
    }
  }

  void _onCancel(PointerCancelEvent e, InfiniteCanvasController controller) {
    _middlePanPointers.remove(e.pointer);
    _pointers.remove(e.pointer);
    if (e.pointer == _primaryPointer) {
      _cancelPrimarySession(controller);
    }
    if (_pointers.length < 2) {
      _pinchStartZoom = null;
      _pinchStartSpan = null;
    }
  }

  void _updateHover(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    if (!config.enableSelection) {
      controller.clearHover();
      return;
    }
    if (_primarySession != _PrimarySession.idle) {
      return;
    }

    final cam = controller.camera;
    final world = cam.localToGlobal(
      event.localPosition.dx,
      event.localPosition.dy,
    );
    final hitId = controller.pickTopNodeAtWorld(world);

    final union = controller.selectedUnionBounds;
    if (controller.selectedQuadIds.isNotEmpty && union != null) {
      final vr = cam.globalToLocalRect(union);
      final handle = SelectionHandles.hitTest(
        viewportRect: vr,
        local: event.localPosition,
        zoom: cam.zoomDouble,
      );
      if (handle != null &&
          (hitId == null || controller.selectedQuadIds.contains(hitId))) {
        controller.setHoveredQuadId(null);
        return;
      }
    }

    if (hitId != null) {
      controller.setHoveredQuadId(hitId);
    } else {
      controller.clearHover();
    }
  }

  void _onScroll(PointerScrollEvent e, InfiniteCanvasController controller) {
    final cam = controller.camera;
    final z = cam.zoomDouble;
    if (z <= 0) return;

    final hw = HardwareKeyboard.instance;
    final metaOrCtrl = hw.isMetaPressed || hw.isControlPressed;
    final shift = hw.isShiftPressed;

    if (config.enableMetaOrControlWheelZoom && metaOrCtrl) {
      final dy = e.scrollDelta.dy;
      if (dy == 0) return;
      final sens = config.wheelZoomSensitivity;
      final factor = 1 + (dy > 0 ? -sens : sens);
      final z0 = cam.zoomDouble;
      final z1 = (z0 * factor).clamp(cam.minZoom, cam.maxZoom);
      if (z1 != z0) {
        _applyZoomTowardsFocal(controller, z1, e.localPosition);
      }
      return;
    }

    if (config.enableShiftWheelHorizontalPan && shift) {
      final dx = e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
      final worldDx = dx * config.wheelHorizontalSensitivity / z;
      cam.moveTo(Offset(cam.position.dx + worldDx, cam.position.dy));
      return;
    }

    if (config.enableWheelVerticalPan) {
      final dy = e.scrollDelta.dy;
      final worldDy = dy * config.wheelVerticalSensitivity / z;
      cam.moveTo(Offset(cam.position.dx, cam.position.dy + worldDy));
    }
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

  static ui.Rect _normalizeWorldRect(ui.Offset a, ui.Offset b) {
    return ui.Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
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
