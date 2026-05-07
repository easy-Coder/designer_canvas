import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

/// Minimal [CanvasNode] for package tests: [TextOpsMixin] + [TextAttributeToggleable].
///
/// [toggleBold] increments [boldToggleCount] so tests can assert formatting hooks fire.
class SmokeTextNode extends CanvasNode with TextOpsMixin implements TextAttributeToggleable {
  SmokeTextNode() : super(style: const BasicNodeStyle());

  static final ui.Rect _bounds = const ui.Rect.fromLTWH(0, 0, 120, 32);

  @override
  ui.Rect get bounds => _bounds;

  String _plain = 'ab';

  @override
  String get text => _plain;

  @override
  set text(String value) {
    _plain = value;
    _editingValue = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  TextEditingValue _editingValue = const TextEditingValue(
    text: 'ab',
    selection: TextSelection.collapsed(offset: 2),
  );

  @override
  TextEditingValue get editingValue => _editingValue;

  @override
  bool isEditing = false;

  @override
  bool caretVisible = false;

  int boldToggleCount = 0;

  @override
  void beginEditing({TextSelection? selection}) {
    _editingValue = TextEditingValue(
      text: _plain,
      selection: selection ?? TextSelection.collapsed(offset: _plain.length),
      composing: TextRange.empty,
    );
    isEditing = true;
    caretVisible = true;
  }

  @override
  void endEditing() {
    isEditing = false;
    caretVisible = false;
    _plain = _editingValue.text;
    _editingValue = TextEditingValue(
      text: _plain,
      selection: TextSelection.collapsed(offset: _plain.length),
      composing: TextRange.empty,
    );
  }

  @override
  void applyEditingValue(TextEditingValue value) {
    _editingValue = value;
    _plain = value.text;
  }

  @override
  TextPainter createTextPainter(double zoom, {String? text}) {
    final t = text ?? _editingValue.text;
    return TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 14 * zoom)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _bounds.width * zoom);
  }

  @override
  TextPosition positionForViewportOffset(ui.Offset viewportOffset, CameraView camera) {
    final tp = createTextPainter(camera.zoomDouble);
    final tl = camera.globalToLocal(_bounds.left, _bounds.top);
    return tp.getPositionForOffset(viewportOffset - tl);
  }

  @override
  void toggleBold() => boldToggleCount++;

  @override
  void toggleItalic() {}

  @override
  void toggleUnderline() {}

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {}
}

/// Extends [NodeStyle] so [NodeOps.applyStyle] tests can toggle a field.
class TintNodeStyle extends NodeStyle {
  const TintNodeStyle([this.tint = const ui.Color(0xFFFF0000)]);

  final ui.Color tint;

  static const String kindValue = 'tint';

  @override
  String get kind => kindValue;

  TintNodeStyle withTint(ui.Color value) => TintNodeStyle(value);

  @override
  TintNodeStyle copyWith() => TintNodeStyle(tint);

  @override
  Map<String, dynamic> toJson() => {'kind': kindValue, 'tint': tint.toARGB32()};
}
