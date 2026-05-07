import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../camera/camera_view.dart';
import '../node/canvas_node.dart';

/// Contract for inline text editing on a [CanvasNode]: IME-driven values,
/// caret visibility, and geometry helpers used by [CanvasTextOps].
///
/// Concrete nodes (e.g. app `TextNode`) mix this in and supply storage.
mixin TextOpsMixin on CanvasNode {
  String get text;

  set text(String value);

  TextEditingValue get editingValue;

  bool get isEditing;

  set isEditing(bool value);

  bool get caretVisible;

  set caretVisible(bool value);

  void beginEditing({TextSelection? selection});

  void endEditing();

  void applyEditingValue(TextEditingValue value);

  TextPainter createTextPainter(double zoom, {String? text});

  TextPosition positionForViewportOffset(ui.Offset viewport, CameraView camera);
}
