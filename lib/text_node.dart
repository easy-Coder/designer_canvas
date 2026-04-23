import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
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
  bool _hasGeometry = false;

  TextNodeStyle get textStyle => style as TextNodeStyle;

  @override
  set style(NodeStyle value) {
    if (value is! TextNodeStyle) return;
    var next = value;
    if (_hasGeometry &&
        textStyle.layoutMode != NodeTextLayoutMode.fixedSize &&
        value.layoutMode == NodeTextLayoutMode.fixedSize) {
      next = value.copyWith(
        fixedWidth: rectWidth,
        fixedHeight: rectHeight,
      );
    }
    super.style = next;
    if (_hasGeometry) {
      _syncGeometry(preserveTopLeft: true);
    }
  }

  double get fontSizeWorld => textStyle.fontSize;

  set fontSizeWorld(double value) {
    style = textStyle.copyWith(fontSize: value);
    _syncGeometry(preserveTopLeft: true);
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
  TextEditingValue _editingValue = const TextEditingValue();
  bool caretVisible = false;

  TextEditingValue get editingValue => _editingValue;

  String get text => _text;

  set text(String value) {
    if (_hasGeometry) {
      _anchor = bounds.topLeft;
    }
    _text = value;
    _editingValue = _editingValue.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
    _syncGeometry(preserveTopLeft: _hasGeometry);
  }

  /// Update the displayed text without recalculating the node's frame geometry.
  /// Use this when the user edits text inline so that position, size, rotation,
  /// and any handle transforms are preserved.
  void updateText(String value) {
    final textChanged = _text != value;
    _text = value;
    final selectionOffset = value.length.clamp(0, value.length);
    _editingValue = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: selectionOffset),
      composing: TextRange.empty,
    );
    if (textChanged &&
        textStyle.layoutMode == NodeTextLayoutMode.autoWidthAutoHeight) {
      _syncGeometry(preserveTopLeft: true);
    }
  }

  void beginEditing({TextSelection? selection}) {
    final nextSelection = selection ?? TextSelection.collapsed(offset: _text.length);
    _editingValue = TextEditingValue(
      text: _text,
      selection: nextSelection,
      composing: TextRange.empty,
    );
    isEditing = true;
    caretVisible = true;
  }

  void endEditing() {
    isEditing = false;
    caretVisible = false;
    _editingValue = TextEditingValue(
      text: _text,
      selection: TextSelection.collapsed(offset: _text.length),
      composing: TextRange.empty,
    );
  }

  void applyEditingValue(TextEditingValue value) {
    final textChanged = _text != value.text;
    _editingValue = value;
    _text = value.text;
    if (textChanged &&
        textStyle.layoutMode == NodeTextLayoutMode.autoWidthAutoHeight) {
      _syncGeometry(preserveTopLeft: true);
    }
  }

  TextPainter createTextPainter(double zoom, {String? text}) {
    final s = textStyle;
    final layoutSize = s.fontSize.clamp(4.0, 512.0);
    return TextPainter(
      text: TextSpan(
        text: text ?? (isEditing ? _editingValue.text : _text),
        style: TextStyle(
          color: s.color,
          fontFamily: s.fontFamily,
          fontStyle: s.fontStyle,
          fontWeight: FontWeight
              .values[((s.fontWeight ~/ 100) - 1).clamp(0, 8)],
          fontSize: layoutSize * zoom,
          shadows: s.shadow == null
              ? null
              : [
                  Shadow(
                    color: s.shadow!.color,
                    offset: ui.Offset(
                      s.shadow!.offsetX * zoom,
                      s.shadow!.offsetY * zoom,
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
        minWidth: rectWidth * zoom,
        maxWidth: rectWidth * zoom,
      );
  }

  ui.Offset textOffsetForCamera(CameraView camera, TextPainter tp) {
    final z = camera.zoomDouble;
    final tl = bounds.topLeft;
    final localTL = camera.globalToLocal(tl.dx, tl.dy);
    final frameHeightPx = rectHeight * z;
    final freeHeightPx = math.max(0.0, frameHeightPx - tp.height);
    final verticalFactor = switch (textStyle.verticalAlign) {
      NodeTextVerticalAlign.top => 0.0,
      NodeTextVerticalAlign.center => 0.5,
      NodeTextVerticalAlign.bottom => 1.0,
    };
    return ui.Offset(localTL.dx, localTL.dy + freeHeightPx * verticalFactor);
  }

  TextPosition positionForViewportOffset(ui.Offset viewportOffset, CameraView camera) {
    final tp = createTextPainter(camera.zoomDouble);
    final textOffset = textOffsetForCamera(camera, tp);
    final localOffset = viewportOffset - textOffset;
    return tp.getPositionForOffset(localOffset);
  }

  (double, double) _frameSize() {
    final s = textStyle;
    if (s.layoutMode == NodeTextLayoutMode.fixedSize) {
      return (
        s.fixedWidth.clamp(24.0, 800.0),
        s.fixedHeight.clamp(fontSizeWorld * 1.35, 800.0),
      );
    }
    final painter = TextPainter(
      text: TextSpan(
        text: _text,
        style: TextStyle(
          fontFamily: s.fontFamily,
          fontStyle: s.fontStyle,
          fontWeight: FontWeight
              .values[((s.fontWeight ~/ 100) - 1).clamp(0, 8)],
          fontSize: s.fontSize.clamp(4.0, 512.0),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout(minWidth: 0, maxWidth: 800.0);
    final intrinsicWidth = painter.maxIntrinsicWidth;
    final w = intrinsicWidth.clamp(24.0, 800.0);
    painter.layout(minWidth: w, maxWidth: w);
    final h = math.max(s.fontSize * 1.35, painter.height);
    return (w, h.clamp(fontSizeWorld * 1.35, 800.0));
  }

  void _syncGeometry({bool preserveTopLeft = false}) {
    final (w, h) = _frameSize();
    final topLeft = preserveTopLeft && _hasGeometry ? bounds.topLeft : _anchor;
    final center = ui.Offset(topLeft.dx + w / 2, topLeft.dy + h / 2);
    initRoundedRectGeometry(
      center: center,
      width: w,
      height: h,
      rotationRadians: _hasGeometry ? rotationRadians : 0,
    );
    _hasGeometry = true;
  }

  @override
  void endTransformSession() {
    super.endTransformSession();
    if (textStyle.layoutMode == NodeTextLayoutMode.fixedSize) {
      super.style = textStyle.copyWith(
        fixedWidth: rectWidth,
        fixedHeight: rectHeight,
      );
    }
    _anchor = bounds.topLeft;
  }

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    super.draw(canvas, context);
    final z = context.camera.zoomDouble;
    final s = textStyle;
    final tp = createTextPainter(z);
    final textOffset = textOffsetForCamera(context.camera, tp);
    final bg = s.backgroundColor;
    if (bg != null) {
      final frameRect = ui.Rect.fromLTWH(
        textOffset.dx,
        context.camera.globalToLocal(bounds.topLeft.dx, bounds.topLeft.dy).dy,
        rectWidth * z,
        rectHeight * z,
      );
      final radiusPx = math.max(0.0, s.backgroundCornerRadius * z);
      canvas.drawRRect(
        ui.RRect.fromRectXY(frameRect, radiusPx, radiusPx),
        ui.Paint()..color = bg,
      );
    }
    if (isEditing && _editingValue.selection.isValid && !_editingValue.selection.isCollapsed) {
      final boxes = tp.getBoxesForSelection(_editingValue.selection);
      final paint = ui.Paint()..color = const ui.Color(0x663382F6);
      for (final box in boxes) {
        canvas.drawRect(box.toRect().shift(textOffset), paint);
      }
    }
    tp.paint(canvas, textOffset);
    if (isEditing && _editingValue.composing.isValid && !_editingValue.composing.isCollapsed) {
      final composeBoxes = tp.getBoxesForSelection(
        TextSelection(
          baseOffset: _editingValue.composing.start,
          extentOffset: _editingValue.composing.end,
        ),
      );
      final composePaint = ui.Paint()..color = const ui.Color(0xFF1565C0);
      for (final box in composeBoxes) {
        final rect = box.toRect().shift(textOffset);
        final underline = ui.Rect.fromLTWH(
          rect.left,
          rect.bottom - 2,
          rect.width,
          2,
        );
        canvas.drawRect(underline, composePaint);
      }
    }
    if (isEditing && caretVisible && _editingValue.selection.isValid && _editingValue.selection.isCollapsed) {
      final clamped = _editingValue.selection.extentOffset.clamp(0, _editingValue.text.length);
      final caretOffset = tp.getOffsetForCaret(
        TextPosition(offset: clamped),
        ui.Rect.fromLTWH(0, 0, 1.5, tp.preferredLineHeight),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          textOffset.dx + caretOffset.dx,
          textOffset.dy + caretOffset.dy,
          1.5,
          tp.preferredLineHeight,
        ),
        ui.Paint()..color = s.color,
      );
    }
  }
}
