import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// View contract for the infinite canvas camera (world ↔ viewport).
///
/// [position] is the **center** of the viewport in **world** coordinates.
/// [zoomDouble] is in \((0, 1]\): larger means more zoomed in (smaller world
/// rectangle visible), matching the model from PlugFox’s canvas article.
abstract interface class CameraView implements Listenable {
  /// Center of the viewport in world coordinates.
  ui.Offset get position;

  /// Pixel size of the viewport (canvas / render box).
  ui.Size get viewportSize;

  /// Visible world axis-aligned rectangle (what the camera shows).
  ui.Rect get bound;

  /// Continuous zoom factor in \((0, 1]\), same semantics as the article.
  double get zoomDouble;

  /// Discrete level in \[1, 10\] derived from [zoomDouble] for API parity.
  int get zoomLevel;

  ui.Offset globalToLocal(double x, double y);

  ui.Offset globalToLocalOffset(ui.Offset offset);

  ui.Rect globalToLocalRect(ui.Rect rect);

  ui.Offset localToGlobal(double x, double y);

  ui.Offset localToGlobalOffset(ui.Offset offset);

  ui.Rect localToGlobalRect(ui.Rect rect);
}
