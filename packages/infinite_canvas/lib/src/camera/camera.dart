import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'camera_view.dart';

/// Default [CameraView] implementation with [ChangeNotifier].
///
/// Transforms match the PlugFox article: [zoomDouble] in \((0, 1]\),
/// [position] is viewport center in world space, [bound] is the visible
/// world rectangle.
class Camera with ChangeNotifier implements CameraView {
  Camera({
    ui.Size viewportSize = ui.Size.zero,
    ui.Offset position = ui.Offset.zero,
    double zoomDouble = 0.5,
    ui.Rect? boundary,
    double minZoom = 0.05,
    double maxZoom = 1.0,
  })  : _position = position,
        _viewportSize = viewportSize,
        _halfViewportSize = viewportSize / 2,
        _bound = ui.Rect.zero,
        _minZoom = minZoom,
        _maxZoom = maxZoom,
        _zoom = zoomDouble.clamp(minZoom, maxZoom),
        _boundary = boundary {
    assert(minZoom > 0 && minZoom <= maxZoom && maxZoom <= 1);
    _calculateBound();
  }

  /// Optional clamp for camera center in world coordinates.
  final ui.Rect? _boundary;

  final double _minZoom;
  final double _maxZoom;

  @override
  ui.Size get viewportSize => _viewportSize;
  ui.Size _viewportSize;
  ui.Size _halfViewportSize;

  @override
  ui.Offset get position => _position;
  ui.Offset _position;

  @override
  ui.Rect get bound => _bound;
  ui.Rect _bound;

  double _zoom;

  @override
  double get zoomDouble => _zoom;

  @override
  int get zoomLevel => ((_zoom * 10).round()).clamp(1, 10);

  double get minZoom => _minZoom;

  double get maxZoom => _maxZoom;

  @override
  @pragma('vm:prefer-inline')
  ui.Offset globalToLocal(double x, double y) => _zoom == 1
      ? ui.Offset(x - _bound.left, y - _bound.top)
      : ui.Offset((x - _bound.left) * _zoom, (y - _bound.top) * _zoom);

  @override
  @pragma('vm:prefer-inline')
  ui.Offset localToGlobal(double x, double y) => _zoom == 1
      ? ui.Offset(x + _bound.left, y + _bound.top)
      : ui.Offset(x / _zoom + _bound.left, y / _zoom + _bound.top);

  @override
  @pragma('vm:prefer-inline')
  ui.Offset globalToLocalOffset(ui.Offset offset) => ui.Offset(
        (offset.dx - _bound.left) * _zoom,
        (offset.dy - _bound.top) * _zoom,
      );

  @override
  @pragma('vm:prefer-inline')
  ui.Offset localToGlobalOffset(ui.Offset offset) => ui.Offset(
        offset.dx / _zoom + _bound.left,
        offset.dy / _zoom + _bound.top,
      );

  @override
  @pragma('vm:prefer-inline')
  ui.Rect globalToLocalRect(ui.Rect rect) => ui.Rect.fromLTRB(
        (rect.left - _bound.left) * _zoom,
        (rect.top - _bound.top) * _zoom,
        (rect.right - _bound.left) * _zoom,
        (rect.bottom - _bound.top) * _zoom,
      );

  @override
  @pragma('vm:prefer-inline')
  ui.Rect localToGlobalRect(ui.Rect rect) => ui.Rect.fromLTRB(
        rect.left / _zoom + _bound.left,
        rect.top / _zoom + _bound.top,
        rect.right / _zoom + _bound.left,
        rect.bottom / _zoom + _bound.top,
      );

  /// Moves the camera so the viewport center sits at [position] in world space.
  bool moveTo(ui.Offset position) {
    var next = position;
    final b = _boundary;
    if (b != null) {
      next = ui.Offset(
        next.dx.clamp(b.left, b.right),
        next.dy.clamp(b.top, b.bottom),
      );
    }
    if (_position == next) return false;
    _position = next;
    _calculateBound();
    notifyListeners();
    return true;
  }

  /// Sync viewport pixel size from the canvas.
  bool changeSize(ui.Size size) {
    if (_viewportSize == size) return false;
    _viewportSize = size;
    _halfViewportSize = size / 2;
    _calculateBound();
    notifyListeners();
    return true;
  }

  /// Sets continuous zoom in \([minZoom, maxZoom]\).
  bool setZoomDouble(double zoom) {
    final z = zoom.clamp(_minZoom, _maxZoom);
    if (_zoom == z) return false;
    _zoom = z;
    _calculateBound();
    notifyListeners();
    return true;
  }

  /// Discrete zoom 1 (most zoomed out) … 10 (most zoomed in), mapped to \[0.1, 1.0\].
  bool changeZoomLevel(int level) {
    final lvl = level.clamp(1, 10);
    return setZoomDouble(lvl / 10.0);
  }

  void zoomIn() => changeZoomLevel(zoomLevel + 1);

  void zoomOut() => changeZoomLevel(zoomLevel - 1);

  void zoomReset() => changeZoomLevel(5);

  @pragma('vm:prefer-inline')
  void _calculateBound() {
    var pos = _position;
    final b = _boundary;
    if (b != null) {
      pos = ui.Offset(
        pos.dx.clamp(b.left, b.right),
        pos.dy.clamp(b.top, b.bottom),
      );
      if (pos != _position) _position = pos;
    }

    // Match article: at max zoom (1.0), half-extent is half viewport in world
    // units; otherwise divide by zoom so a smaller world window is visible.
    if (_zoom >= 1.0) {
      _bound = ui.Rect.fromLTRB(
        _position.dx - _halfViewportSize.width,
        _position.dy - _halfViewportSize.height,
        _position.dx + _halfViewportSize.width,
        _position.dy + _halfViewportSize.height,
      );
    } else {
      _bound = ui.Rect.fromLTRB(
        _position.dx - _halfViewportSize.width / _zoom,
        _position.dy - _halfViewportSize.height / _zoom,
        _position.dx + _halfViewportSize.width / _zoom,
        _position.dy + _halfViewportSize.height / _zoom,
      );
    }
  }
}
