import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'node_styles.dart';
/// Text in a heuristic [RoundedRectCanvasMixin] frame; paint uses [bounds]
/// top-left after transforms.
class TextNode extends CanvasNode with RoundedRectCanvasMixin {
  TextNode({
    required ui.Offset position,
    required String text,
    TextNodeStyle? style,
    String? label,
    super.zIndex = 1,
  }) : _anchor = position,
        _text = text {
    this.style = style ?? const TextNodeStyle();
    this.label = label ?? 'Text';
    _syncGeometry();
  }

  ui.Offset _anchor;
  String _text;

  TextNodeStyle get textStyle => style as TextNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! TextNodeStyle) return;
    super.style = value;
  }

  double get fontSizeWorld => textStyle.fontSize;

  set fontSizeWorld(double value) {
    style = textStyle.copyWith(fontSize: value);
    _syncGeometry();
  }

  ui.Color get color => textStyle.color;

  set color(ui.Color value) {
    style = textStyle.copyWith(color: value);
  }

  TextAlign get textAlign {
    return switch (textStyle.textAlign) {
      NodeTextAlign.left => TextAlign.left,
      NodeTextAlign.center => TextAlign.center,
      NodeTextAlign.right => TextAlign.right,
    };
  }

  set textAlign(TextAlign value) {
    style = textStyle.copyWith(
      textAlign: switch (value) {
        TextAlign.center => NodeTextAlign.center,
        TextAlign.right => NodeTextAlign.right,
        _ => NodeTextAlign.left,
      },
    );
  }

  NodeTextVerticalAlign get verticalAlign => textStyle.verticalAlign;

  set verticalAlign(NodeTextVerticalAlign value) {
    style = textStyle.copyWith(verticalAlign: value);
  }

  ui.Color? get backgroundColor => textStyle.backgroundColor;

  set backgroundColor(ui.Color? value) {
    style = textStyle.copyWith(
      backgroundColor: value,
      clearBackgroundColor: value == null,
    );
  }

  double get backgroundCornerRadiusWorld => textStyle.backgroundCornerRadius;

  set backgroundCornerRadiusWorld(double value) {
    style = textStyle.copyWith(backgroundCornerRadius: value);
  }

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
    final s = textStyle;
    final z = context.camera.zoomDouble;
    final layoutSize = s.fontSize.clamp(4.0, 512.0);
    final tp = TextPainter(
      text: TextSpan(
        text: _text,
        style: TextStyle(
          color: s.color,
          fontFamily: s.fontFamily,
          fontStyle: s.fontStyle,
          fontWeight: FontWeight
              .values[((s.fontWeight ~/ 100) - 1).clamp(0, 8)],
          fontSize: layoutSize * z,
          shadows: s.shadow == null
              ? null
              : [
                  Shadow(
                    color: s.shadow!.color,
                    offset: ui.Offset(
                      s.shadow!.offsetX * z,
                      s.shadow!.offsetY * z,
                    ),
                    blurRadius: s.shadow!.blurRadius,
                  ),
                ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (s.textAlign) {
        NodeTextAlign.left => TextAlign.left,
        NodeTextAlign.center => TextAlign.center,
        NodeTextAlign.right => TextAlign.right,
      },
    )..layout(
        minWidth: rectWidth * z,
        maxWidth: rectWidth * z,
      );
    final tl = bounds.topLeft;
    final localTL = context.camera.globalToLocal(tl.dx, tl.dy);
    final frameHeightPx = rectHeight * z;
    final freeHeightPx = math.max(0.0, frameHeightPx - tp.height);
    final verticalFactor = switch (s.verticalAlign) {
      NodeTextVerticalAlign.top => 0.0,
      NodeTextVerticalAlign.center => 0.5,
      NodeTextVerticalAlign.bottom => 1.0,
    };
    final textOffset = ui.Offset(
      localTL.dx,
      localTL.dy + freeHeightPx * verticalFactor,
    );
    final bg = s.backgroundColor;
    if (bg != null) {
      final frameRect = ui.Rect.fromLTWH(
        localTL.dx,
        localTL.dy,
        rectWidth * z,
        frameHeightPx,
      );
      final radiusPx = math.max(0.0, s.backgroundCornerRadius * z);
      canvas.drawRRect(
        ui.RRect.fromRectXY(frameRect, radiusPx, radiusPx),
        ui.Paint()..color = bg,
      );
    }
    tp.paint(canvas, textOffset);
  }
}
