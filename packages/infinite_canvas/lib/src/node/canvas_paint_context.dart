import 'dart:ui' as ui;

import '../camera/camera_view.dart';
import 'canvas_node.dart';

/// Per-frame drawing helpers for a [CanvasNode] and the active [CameraView].
class CanvasPaintContext {
  CanvasPaintContext({
    required this.camera,
    required this.node,
  });

  final CameraView camera;
  final CanvasNode node;

  /// Maps a world-space rectangle to viewport (canvas) pixels.
  ui.Rect worldRectToViewport(ui.Rect world) => camera.globalToLocalRect(world);

  /// Camera zoom × [CanvasNode.worldScale] for strokes and layout that should
  /// grow/shrink with zoom consistently.
  double get combinedScale => camera.zoomDouble * node.worldScale;

  /// A stroke width that stays visually thin at high zoom.
  ///
  /// Uses `1 / combinedScale` so line thickness in **world** units stays
  /// roughly constant on screen when [combinedScale] grows.
  double get hairlineStrokeWidth {
    final s = combinedScale;
    if (s <= 0) return 1;
    return (1 / s).clamp(0.5, 8.0);
  }
}
