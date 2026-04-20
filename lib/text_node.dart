import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

/// Text in a heuristic [RoundedRectCanvasMixin] frame; paint uses [bounds]
/// top-left after transforms.
class TextNode extends CanvasNode with RoundedRectCanvasMixin {
  TextNode({
    required ui.Offset position,
    required String text,
    this.fontSizeWorld = 18,
    required this.color,
    super.zIndex = 1,
  })  : _anchor = position,
        _text = text {
    _syncGeometry();
  }

  ui.Offset _anchor;
  String _text;
  double fontSizeWorld;
  final ui.Color color;

  /// When true, `draw()` skips painting the text so the overlay [TextField]
  /// isn't doubled. The rounded-rect background is still painted.
  bool isEditing = false;

  String get text => _text;

  set text(String value) {
    _anchor = bounds.topLeft;
    _text = value;
    _syncGeometry();
  }

  /// Update the displayed text without recalculating the node's frame geometry.
  /// Use this when the user edits text inline so that position, size, rotation,
  /// and any handle transforms are preserved.
  void updateText(String value) {
    _text = value;
  }

  (double, double) _frameSize() {
    final w = math
        .min(
          800.0,
          math.max(24.0, _text.length * fontSizeWorld * 0.45),
        )
        .toDouble();
    final h = fontSizeWorld * 1.35;
    return (w, h);
  }

  void _syncGeometry() {
    final (w, h) = _frameSize();
    final center = ui.Offset(_anchor.dx + w / 2, _anchor.dy + h / 2);
    initRoundedRectGeometry(
      center: center,
      width: w,
      height: h,
      rotationRadians: 0,
    );
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    if (isEditing) return;
    final z = context.camera.zoomDouble;
    final layoutSize = fontSizeWorld.clamp(4.0, 512.0);
    final tp = TextPainter(
      text: TextSpan(
        text: _text,
        style: TextStyle(
          color: color,
          fontSize: layoutSize * z,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rectWidth * z);
    final tl = bounds.topLeft;
    final localTL = context.camera.globalToLocal(tl.dx, tl.dy);
    tp.paint(canvas, localTL);
  }
}
