/// Pure, host-agnostic edit operations for canvas text editors.
///
/// These helpers manipulate [TextEditingValue] / [TextSelection] and are the
/// common building blocks invoked from key/pointer handlers in a canvas text
/// editor. They never touch a node, document, or controller, so they can be
/// reused by any consumer of `package:infinite_canvas`.
///
/// The painter-based helpers ([moveVerticalWithPainter],
/// [lineSelectionAtOffsetWithPainter]) take a pre-built [TextPainter] so the
/// caller controls font, scale, and layout — typically the same [TextPainter]
/// your node uses for painting at the current zoom.
///
/// ## Example
///
/// ```dart
/// // Arrow-left:
/// final next = moveHorizontal(value, true, expandSelection: shift);
///
/// // Arrow-down (caller builds the painter at current zoom):
/// final painter = node.createTextPainter(camera.zoomDouble, text: value.text);
/// final next = moveVerticalWithPainter(value, painter, false,
///     expandSelection: shift);
///
/// // Triple-click line selection:
/// final line = lineSelectionAtOffsetWithPainter(painter, value.text, hitOffset);
/// ```
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Returns the UTF-16 index before [offset], or `0` if already at the start.
int previousOffset(String text, int offset) {
  if (offset <= 0) return 0;
  return offset - 1;
}

/// Returns the UTF-16 index after [offset], or `text.length` if already at the end.
int nextOffset(String text, int offset) {
  if (offset >= text.length) return text.length;
  return offset + 1;
}

/// Collapses the selection to a single caret, clamping [offset] to `[0, text.length]`.
TextEditingValue collapseToOffset(TextEditingValue value, int offset) {
  final clamped = offset.clamp(0, value.text.length);
  return value.copyWith(selection: TextSelection.collapsed(offset: clamped));
}

/// Deletes the current non-collapsed range and clears composing.
///
/// Returns [value] unchanged when the selection is invalid or collapsed.
TextEditingValue deleteSelection(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || selection.isCollapsed) return value;
  final start = math.min(selection.start, selection.end);
  final end = math.max(selection.start, selection.end);
  final nextText = value.text.replaceRange(start, end, '');
  return TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: start),
    composing: TextRange.empty,
  );
}

/// Deletes one UTF-16 code unit before the caret when collapsed; otherwise
/// behaves like [deleteSelection].
///
/// Returns [value] unchanged when the selection is invalid, when the caret is
/// already at offset `0`, or when there is nothing to delete.
TextEditingValue deleteBackward(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  if (!selection.isCollapsed) return deleteSelection(value);
  if (selection.extentOffset <= 0) return value;
  final at = selection.extentOffset;
  final prev = previousOffset(value.text, at);
  final nextText = value.text.replaceRange(prev, at, '');
  return TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: prev),
    composing: TextRange.empty,
  );
}

/// Deletes one UTF-16 code unit after the caret when collapsed; otherwise
/// behaves like [deleteSelection].
///
/// Returns [value] unchanged when the selection is invalid or the caret is
/// already at the end of the string.
TextEditingValue deleteForward(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  if (!selection.isCollapsed) return deleteSelection(value);
  final at = selection.extentOffset;
  if (at >= value.text.length) return value;
  final next = nextOffset(value.text, at);
  final nextText = value.text.replaceRange(at, next, '');
  return TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: at),
    composing: TextRange.empty,
  );
}

/// Moves the caret or selection horizontally by one code unit.
///
/// When [expandSelection] is true, the base stays fixed and the extent moves.
/// When false and the selection is ranged, the caret jumps to the min or max
/// edge (depending on [moveLeft]) without deleting text. When false and
/// collapsed, the caret moves one step left or right.
///
/// Returns [value] unchanged if the current selection is invalid.
TextEditingValue moveHorizontal(
  TextEditingValue value,
  bool moveLeft, {
  required bool expandSelection,
}) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  if (expandSelection) {
    final current = selection.extentOffset;
    final target = moveLeft
        ? previousOffset(value.text, current)
        : nextOffset(value.text, current);
    return value.copyWith(
      selection: TextSelection(
        baseOffset: selection.baseOffset,
        extentOffset: target,
      ),
    );
  }
  if (!selection.isCollapsed) {
    final target = moveLeft
        ? math.min(selection.baseOffset, selection.extentOffset)
        : math.max(selection.baseOffset, selection.extentOffset);
    return collapseToOffset(value, target);
  }
  final current = selection.extentOffset;
  final target = moveLeft
      ? previousOffset(value.text, current)
      : nextOffset(value.text, current);
  return collapseToOffset(value, target);
}

/// `true` when [codeUnit] is *not* in `[A-Za-z0-9_]`.
///
/// Used by [wordStart] / [wordEnd] for a deliberately simple notion of "word":
/// full Unicode word breaking is out of scope here.
bool isWordBoundaryCodeUnit(int codeUnit) {
  final c = String.fromCharCode(codeUnit);
  return !RegExp(r'[A-Za-z0-9_]').hasMatch(c);
}

/// Returns the start offset of the word containing [offset] (per
/// [isWordBoundaryCodeUnit]), clamped into the string.
int wordStart(String text, int offset) {
  var i = offset.clamp(0, text.length);
  while (i > 0 && isWordBoundaryCodeUnit(text.codeUnitAt(i - 1))) {
    i--;
  }
  while (i > 0 && !isWordBoundaryCodeUnit(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}

/// Returns the end offset of the word containing [offset] (per
/// [isWordBoundaryCodeUnit]), clamped into the string.
int wordEnd(String text, int offset) {
  var i = offset.clamp(0, text.length);
  while (i < text.length && isWordBoundaryCodeUnit(text.codeUnitAt(i))) {
    i++;
  }
  while (i < text.length && !isWordBoundaryCodeUnit(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

/// Moves the caret or selection vertically using [painter] line geometry.
///
/// The caret's pixel position is sampled one [TextPainter.preferredLineHeight]
/// above or below, then mapped back to a [TextPosition]. [painter] must already
/// be laid out for the same `value.text` you pass in, or vertical motion will
/// not match what the user sees.
///
/// Preserves [TextEditingValue.composing] on the returned value.
///
/// Returns [value] unchanged if the current selection is invalid.
TextEditingValue moveVerticalWithPainter(
  TextEditingValue value,
  TextPainter painter,
  bool moveUp, {
  required bool expandSelection,
}) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  final caretOffset = selection.extentOffset.clamp(0, value.text.length);
  final caret = painter.getOffsetForCaret(
    TextPosition(offset: caretOffset),
    ui.Rect.fromLTWH(0, 0, 1, painter.preferredLineHeight),
  );
  final dy = moveUp
      ? -painter.preferredLineHeight
      : painter.preferredLineHeight;
  final probe = ui.Offset(caret.dx, caret.dy + dy);
  final nextPos = painter.getPositionForOffset(probe);
  if (expandSelection) {
    return value.copyWith(
      selection: TextSelection(
        baseOffset: selection.baseOffset,
        extentOffset: nextPos.offset,
      ),
      composing: value.composing,
    );
  }
  return collapseToOffset(
    value,
    nextPos.offset,
  ).copyWith(composing: value.composing);
}

/// Returns the selection covering the full visual line that contains [offset].
///
/// [painter] must be laid out for [text]. If [painter.computeLineMetrics] is
/// empty, returns [TextSelection.collapsed] at the clamped [offset].
TextSelection lineSelectionAtOffsetWithPainter(
  TextPainter painter,
  String text,
  int offset,
) {
  final clamped = offset.clamp(0, text.length);
  final caret = painter.getOffsetForCaret(
    TextPosition(offset: clamped),
    ui.Rect.fromLTWH(0, 0, 1, painter.preferredLineHeight),
  );
  final metrics = painter.computeLineMetrics();
  if (metrics.isEmpty) {
    return TextSelection.collapsed(offset: clamped);
  }
  final line = metrics.firstWhere(
    (m) =>
        caret.dy >= m.baseline - m.ascent &&
        caret.dy <= m.baseline + m.descent,
    orElse: () => metrics.last,
  );
  final y = line.baseline - (line.ascent / 2);
  final start = painter.getPositionForOffset(ui.Offset(0, y)).offset;
  final end = painter
      .getPositionForOffset(ui.Offset(painter.width + 1000, y))
      .offset;
  return TextSelection(baseOffset: start, extentOffset: end);
}
