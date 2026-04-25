import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'canvas_text_ime_client.dart';
import 'canvas_tool.dart';
import 'circle_node.dart';
import 'line_node.dart';
import 'rect_node.dart';
import 'text_node.dart';
import 'tool_style_defaults.dart';
import 'triangle_node.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

const int _kPrimaryMouseButton = 0x01;
const Duration _kDoubleClickTimeout = Duration(milliseconds: 350);
const double _kDoubleClickMaxDistance = 8.0;
const int _kDragModeChar = 0;
const int _kDragModeWord = 1;
const int _kDragModeLine = 2;

/// Forwards to [DefaultInfiniteCanvasGestureHandler] in [CanvasTool.select];
/// in other tools, primary pointer creates nodes (drag or tap).
class DesignerGestureHandler extends InfiniteCanvasGestureHandler {
  DesignerGestureHandler({
    required this.tool,
    required this.toolDefaults,
    required this.delegate,
    required this.gestureConfig,
    required this.canvasFocusNode,
    required this.startCursorBlink,
    required this.stopCursorBlink,
    required this.isCursorVisible,
  });

  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;
  final DefaultInfiniteCanvasGestureHandler delegate;
  final InfiniteCanvasGestureConfig gestureConfig;
  final FocusNode canvasFocusNode;
  final VoidCallback startCursorBlink;
  final VoidCallback stopCursorBlink;
  final bool Function() isCursorVisible;

  /// Currently edited text node, or null.
  final ValueNotifier<({int quadId, TextNode node})?> _editingText =
      ValueNotifier(null);
  CanvasTextImeClient? _imeClient;
  String? _editSnapshot;
  int? _textDragPointer;
  int? _textDragAnchorOffset;
  int _textDragMode = _kDragModeChar;
  int _selectionAnchorOffset = 0;
  Duration? _lastTextPointerDownAt;
  ui.Offset? _lastTextPointerDownLocal;
  int _textClickCount = 0;

  @override
  int? get activeEditingQuadId => _editingText.value?.quadId;

  void _applyEditingValue(
    InfiniteCanvasController controller,
    TextEditingValue next,
  ) {
    final editing = _editingText.value;
    if (editing == null) return;
    editing.node.applyEditingValue(next);
    editing.node.caretVisible = true;
    _imeClient?.updateLocalValue(next);
    controller.updateNode(editing.quadId);
    controller.requestRepaint();
  }

  int _previousOffset(String text, int offset) {
    if (offset <= 0) return 0;
    return offset - 1;
  }

  int _nextOffset(String text, int offset) {
    if (offset >= text.length) return text.length;
    return offset + 1;
  }

  TextEditingValue _collapseToOffset(TextEditingValue value, int offset) {
    final clamped = offset.clamp(0, value.text.length);
    return value.copyWith(selection: TextSelection.collapsed(offset: clamped));
  }

  TextEditingValue _deleteSelection(TextEditingValue value) {
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

  TextEditingValue _deleteBackward(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid) return value;
    if (!selection.isCollapsed) return _deleteSelection(value);
    if (selection.extentOffset <= 0) return value;
    final at = selection.extentOffset;
    final prev = _previousOffset(value.text, at);
    final nextText = value.text.replaceRange(prev, at, '');
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: prev),
      composing: TextRange.empty,
    );
  }

  TextEditingValue _deleteForward(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid) return value;
    if (!selection.isCollapsed) return _deleteSelection(value);
    final at = selection.extentOffset;
    if (at >= value.text.length) return value;
    final next = _nextOffset(value.text, at);
    final nextText = value.text.replaceRange(at, next, '');
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: at),
      composing: TextRange.empty,
    );
  }

  TextEditingValue _moveHorizontal(
    TextEditingValue value,
    bool moveLeft, {
    required bool expandSelection,
  }) {
    final selection = value.selection;
    if (!selection.isValid) return value;
    if (expandSelection) {
      final current = selection.extentOffset;
      final target = moveLeft
          ? _previousOffset(value.text, current)
          : _nextOffset(value.text, current);
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
      return _collapseToOffset(value, target);
    }
    final current = selection.extentOffset;
    final target = moveLeft
        ? _previousOffset(value.text, current)
        : _nextOffset(value.text, current);
    return _collapseToOffset(value, target);
  }

  TextEditingValue _moveVertical(
    TextEditingValue value,
    TextNode node,
    CameraView camera,
    bool moveUp, {
    required bool expandSelection,
  }) {
    final selection = value.selection;
    if (!selection.isValid) return value;
    final caretOffset = selection.extentOffset.clamp(0, value.text.length);
    final painter = node.createTextPainter(camera.zoomDouble, text: value.text);
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
    return _collapseToOffset(
      value,
      nextPos.offset,
    ).copyWith(composing: value.composing);
  }

  bool _isWordBoundaryCodeUnit(int codeUnit) {
    final c = String.fromCharCode(codeUnit);
    return !RegExp(r'[A-Za-z0-9_]').hasMatch(c);
  }

  int _wordStart(String text, int offset) {
    var i = offset.clamp(0, text.length);
    while (i > 0 && _isWordBoundaryCodeUnit(text.codeUnitAt(i - 1))) {
      i--;
    }
    while (i > 0 && !_isWordBoundaryCodeUnit(text.codeUnitAt(i - 1))) {
      i--;
    }
    return i;
  }

  int _wordEnd(String text, int offset) {
    var i = offset.clamp(0, text.length);
    while (i < text.length && _isWordBoundaryCodeUnit(text.codeUnitAt(i))) {
      i++;
    }
    while (i < text.length && !_isWordBoundaryCodeUnit(text.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  TextSelection _lineSelectionAtOffset(
    TextNode node,
    CameraView camera,
    String text,
    int offset,
  ) {
    final clamped = offset.clamp(0, text.length);
    final painter = node.createTextPainter(camera.zoomDouble, text: text);
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

  /// Start inline editing for [node] at [quadId].
  void startEditing(
    int quadId,
    TextNode node,
    InfiniteCanvasController controller,
  ) {
    stopEditing(controller, commit: true);
    _editSnapshot = node.text;
    node.beginEditing(
      selection: TextSelection.collapsed(offset: node.text.length),
    );
    node.caretVisible = isCursorVisible();
    _editingText.value = (quadId: quadId, node: node);
    _imeClient ??= CanvasTextImeClient(
      onValueChanged: (value) {
        final editing = _editingText.value;
        if (editing == null) return;
        editing.node.applyEditingValue(value);
        editing.node.caretVisible = isCursorVisible();
        controller.updateNode(editing.quadId);
        controller.requestRepaint();
      },
      onDone: () => stopEditing(controller, commit: true),
      onConnectionClosed: () => stopEditing(controller, commit: true),
    );
    _imeClient!.attach(
      configuration: TextInputConfiguration(
        inputType: TextInputType.multiline,
        inputAction: TextInputAction.newline,
        enableDeltaModel: true,
        autocorrect: true,
        enableSuggestions: true,
        keyboardAppearance: Brightness.dark,
      ),
      value: node.editingValue,
    );
    canvasFocusNode.requestFocus();
    _imeClient!.show();
    startCursorBlink();
    controller.requestRepaint();
  }

  void updateEditingCaretVisibility(InfiniteCanvasController controller) {
    final editing = _editingText.value;
    if (editing == null) return;
    editing.node.caretVisible = isCursorVisible();
    controller.requestRepaint();
  }

  void handleCanvasFocusChanged(
    bool hasFocus,
    InfiniteCanvasController controller,
  ) {
    // Keep editing alive even if sidebars temporarily take focus.
    // Explicit exit paths (outside tap, Escape, IME done/close) still apply.
    if (!hasFocus && _editingText.value == null) return;
  }

  void dispose() {
    _imeClient?.close();
  }

  /// Commit current text and close the editor.
  void stopEditing(
    InfiniteCanvasController? controller, {
    required bool commit,
  }) {
    final editing = _editingText.value;
    if (editing == null) return;
    if (!commit && _editSnapshot != null) {
      editing.node.updateText(_editSnapshot!);
    } else {
      editing.node.updateText(editing.node.editingValue.text);
    }
    editing.node.endEditing();
    stopCursorBlink();
    _imeClient?.close();
    _editSnapshot = null;
    _editingText.value = null;
    _textDragPointer = null;
    _textDragAnchorOffset = null;
    _textDragMode = _kDragModeChar;
    _selectionAnchorOffset = 0;
    _textClickCount = 0;
    if (controller != null) {
      controller.updateNode(editing.quadId);
      controller.requestRepaint();
    }
  }

  // ─── Placement state ─────────────────────────────────────────────────
  int? _placePointer;
  ui.Offset? _placeWorldStart;
  CanvasTool? _placeTool;
  int? _placeQuadId;

  static ui.Rect _normalizeWorldRect(ui.Offset a, ui.Offset b) {
    return ui.Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }

  double _minWorldSize(InfiniteCanvasController controller) =>
      24 / controller.camera.zoomDouble;

  double _slopWorld(InfiniteCanvasController controller) =>
      gestureConfig.selectionSlopPixels / controller.camera.zoomDouble;

  /// World-space size for the initial preview quad so indexing stays valid.
  double _previewSeed(InfiniteCanvasController controller) =>
      (1 / controller.camera.zoomDouble).clamp(1e-6, 100.0);

  void _clearPlacement() {
    _placePointer = null;
    _placeWorldStart = null;
    _placeTool = null;
    _placeQuadId = null;
  }

  void _switchToSelectTool() {
    if (tool.value != CanvasTool.select) {
      tool.value = CanvasTool.select;
    }
  }

  void _beginPreviewNode(
    InfiniteCanvasController controller,
    ui.Offset start,
    CanvasTool t,
  ) {
    final eps = _previewSeed(controller);
    switch (t) {
      case CanvasTool.select:
        break;
      case CanvasTool.text:
        break;
      case CanvasTool.rect:
        final r = ui.Rect.fromCenter(center: start, width: eps, height: eps);
        _placeQuadId = controller.addNode(
          RectNode.fromAxisAlignedRect(
            r,
            style: toolDefaults.value.rect,
            zIndex: 2,
          ),
        );
      case CanvasTool.circle:
        _placeQuadId = controller.addNode(
          CircleNode(
            center: start,
            radius: eps / 2,
            style: toolDefaults.value.circle,
            zIndex: 2,
          ),
        );
      case CanvasTool.triangle:
        _placeQuadId = controller.addNode(
          TriangleNode(
            center: start,
            side: eps,
            style: toolDefaults.value.triangle,
            zIndex: 2,
          ),
        );
      case CanvasTool.line:
        _placeQuadId = controller.addNode(
          LineNode(
            start: start,
            end: ui.Offset(start.dx + eps, start.dy),
            style: toolDefaults.value.line,
            zIndex: 2,
          ),
        );
    }
  }

  void _applyPreviewGeometry(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end, {
    required bool lineFinalize,
  }) {
    final id = _placeQuadId;
    final t = _placeTool;
    if (id == null || t == null) return;

    final minW = _minWorldSize(controller);
    final node = controller.lookupNode(id);
    if (node == null) return;

    switch (t) {
      case CanvasTool.select:
      case CanvasTool.text:
        break;
      case CanvasTool.rect:
        (node as RectNode).setAxisAlignedWorldRect(
          _normalizeWorldRect(start, end),
        );
        controller.updateNode(id);
      case CanvasTool.circle:
        final r = _normalizeWorldRect(start, end);
        final radius = math.min(r.width, r.height) / 2;
        (node as CircleNode).setCenterAndRadius(r.center, radius);
        controller.updateNode(id);
      case CanvasTool.triangle:
        final r = _normalizeWorldRect(start, end);
        final side = math.min(r.width, r.height);
        (node as TriangleNode).setCenterAndSide(r.center, side);
        controller.updateNode(id);
      case CanvasTool.line:
        var a = start;
        var b = end;
        if (lineFinalize && (b - a).distance < minW) {
          b = ui.Offset(a.dx + minW, a.dy);
        }
        (node as LineNode).setWorldEndpoints(a, b);
        controller.updateNode(id);
    }
  }

  bool _previewBelowMinSize(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
  ) {
    final minW = _minWorldSize(controller);
    final t = _placeTool;
    if (t == null) return true;
    switch (t) {
      case CanvasTool.rect:
      case CanvasTool.circle:
      case CanvasTool.triangle:
        final r = _normalizeWorldRect(start, end);
        return r.width < minW || r.height < minW;
      case CanvasTool.select:
      case CanvasTool.text:
      case CanvasTool.line:
        return false;
    }
  }

  void _finalizePlacement(
    InfiniteCanvasController controller,
    ui.Offset start,
    ui.Offset end,
  ) {
    final t = _placeTool;
    final id = _placeQuadId;
    final slop = _slopWorld(controller);

    if (t == CanvasTool.text) {
      if ((end - start).distance <= slop) {
        final newId = controller.addNode(
          TextNode(
            position: start,
            text: 'Text',
            style: toolDefaults.value.text,
            zIndex: 2,
          ),
        );
        controller.selectSingle(newId);
        final node = controller.lookupNode(newId);
        if (node is TextNode) {
          startEditing(newId, node, controller);
        }
        _switchToSelectTool();
      }
      controller.requestRepaint();
      return;
    }

    if (id == null || t == null || t == CanvasTool.select) {
      controller.requestRepaint();
      return;
    }

    if (t == CanvasTool.line) {
      _applyPreviewGeometry(controller, start, end, lineFinalize: true);
      controller.selectSingle(id);
      _switchToSelectTool();
      controller.requestRepaint();
      return;
    }

    if (_previewBelowMinSize(controller, start, end)) {
      controller.removeNode(id);
    } else {
      _applyPreviewGeometry(controller, start, end, lineFinalize: false);
      controller.selectSingle(id);
      _switchToSelectTool();
    }
    controller.requestRepaint();
  }

  @override
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {
    if (event is PointerScrollEvent || event is PointerPanZoomUpdateEvent) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    if (tool.value != CanvasTool.select) {
      controller.clearHover();
    }

    if (_editingText.value != null && _textDragPointer != null) {
      final editing = _editingText.value!;
      if (event.pointer == _textDragPointer && event is PointerMoveEvent) {
        final anchor =
            _textDragAnchorOffset ??
            editing.node.editingValue.selection.baseOffset;
        final position = editing.node.positionForViewportOffset(
          event.localPosition,
          controller.camera,
        );
        final extentOffset = position.offset;
        final nextSelection = switch (_textDragMode) {
          _kDragModeWord =>
            extentOffset >= anchor
                ? TextSelection(
                    baseOffset: _wordStart(
                      editing.node.editingValue.text,
                      anchor,
                    ),
                    extentOffset: _wordEnd(
                      editing.node.editingValue.text,
                      extentOffset,
                    ),
                  )
                : TextSelection(
                    baseOffset: _wordEnd(
                      editing.node.editingValue.text,
                      anchor,
                    ),
                    extentOffset: _wordStart(
                      editing.node.editingValue.text,
                      extentOffset,
                    ),
                  ),
          _kDragModeLine => TextSelection(
            baseOffset: _lineSelectionAtOffset(
              editing.node,
              controller.camera,
              editing.node.editingValue.text,
              anchor,
            ).baseOffset,
            extentOffset: _lineSelectionAtOffset(
              editing.node,
              controller.camera,
              editing.node.editingValue.text,
              extentOffset,
            ).extentOffset,
          ),
          _ => TextSelection(baseOffset: anchor, extentOffset: extentOffset),
        };
        final nextValue = editing.node.editingValue.copyWith(
          selection: nextSelection,
        );
        _applyEditingValue(controller, nextValue);
        return;
      }

      if (event.pointer == _textDragPointer &&
          (event is PointerUpEvent || event is PointerCancelEvent)) {
        _textDragPointer = null;
        _textDragAnchorOffset = null;
        _textDragMode = _kDragModeChar;
        return;
      }
    }

    if (event is PointerDownEvent && _editingText.value != null) {
      final editing = _editingText.value!;
      final world = controller.camera.localToGlobal(
        event.localPosition.dx,
        event.localPosition.dy,
      );
      final toleranceWorld = 8.0 / controller.camera.zoomDouble;
      final hitBounds = editing.node.bounds.inflate(toleranceWorld);
      if (hitBounds.contains(world)) {
        canvasFocusNode.requestFocus();
        final position = editing.node.positionForViewportOffset(
          event.localPosition,
          controller.camera,
        );
        final now = event.timeStamp;
        final isRepeatedClick =
            _lastTextPointerDownAt != null &&
            (now - _lastTextPointerDownAt!) <= _kDoubleClickTimeout &&
            _lastTextPointerDownLocal != null &&
            (event.localPosition - _lastTextPointerDownLocal!).distance <=
                _kDoubleClickMaxDistance;
        _textClickCount = isRepeatedClick
            ? (_textClickCount + 1).clamp(1, 4)
            : 1;
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        final offset = position.offset;
        final current = editing.node.editingValue.selection;
        late final TextSelection selection;
        late final int dragMode;
        late final int anchor;
        if (isShiftPressed && _textClickCount == 1) {
          anchor = current.isValid
              ? current.baseOffset
              : _selectionAnchorOffset;
          selection = TextSelection(baseOffset: anchor, extentOffset: offset);
          dragMode = _kDragModeChar;
        } else if (_textClickCount == 2) {
          final start = _wordStart(editing.node.editingValue.text, offset);
          final end = _wordEnd(editing.node.editingValue.text, offset);
          selection = TextSelection(baseOffset: start, extentOffset: end);
          anchor = start;
          dragMode = _kDragModeWord;
        } else if (_textClickCount == 3) {
          selection = _lineSelectionAtOffset(
            editing.node,
            controller.camera,
            editing.node.editingValue.text,
            offset,
          );
          anchor = selection.baseOffset;
          dragMode = _kDragModeLine;
        } else if (_textClickCount >= 4) {
          selection = TextSelection(
            baseOffset: 0,
            extentOffset: editing.node.editingValue.text.length,
          );
          anchor = 0;
          dragMode = _kDragModeChar;
        } else {
          selection = TextSelection.collapsed(offset: offset);
          anchor = offset;
          dragMode = _kDragModeChar;
        }
        final nextValue = editing.node.editingValue.copyWith(
          selection: selection,
        );
        _textDragPointer = event.pointer;
        _textDragAnchorOffset = anchor;
        _selectionAnchorOffset = anchor;
        _textDragMode = dragMode;
        _lastTextPointerDownAt = now;
        _lastTextPointerDownLocal = event.localPosition;
        _applyEditingValue(controller, nextValue);
        return;
      }
      _textDragPointer = null;
      _textDragAnchorOffset = null;
      _textDragMode = _kDragModeChar;
      stopEditing(controller, commit: true);
    }

    if (tool.value == CanvasTool.select) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    final cam = controller.camera;
    if (event is PointerDownEvent) {
      if ((event.buttons & _kPrimaryMouseButton) == 0 ||
          (event.buttons & kMiddleMouseButton) != 0) {
        delegate.handlePointerEvent(event, controller);
        return;
      }
      _placePointer = event.pointer;
      _placeWorldStart = cam.localToGlobal(
        event.localPosition.dx,
        event.localPosition.dy,
      );
      _placeTool = tool.value;
      _placeQuadId = null;
      final start = _placeWorldStart!;
      _beginPreviewNode(controller, start, _placeTool!);
      return;
    }

    if (_placePointer == null) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    if (event.pointer != _placePointer) {
      delegate.handlePointerEvent(event, controller);
      return;
    }

    if (event is PointerMoveEvent) {
      final start = _placeWorldStart;
      if (start != null && _placeQuadId != null) {
        final cur = cam.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        _applyPreviewGeometry(controller, start, cur, lineFinalize: false);
      } else if (start != null && _placeTool == CanvasTool.text) {
        controller.requestRepaint();
      }
      return;
    }

    if (event is PointerUpEvent) {
      final start = _placeWorldStart;
      if (start != null) {
        final upWorld = cam.localToGlobal(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        _finalizePlacement(controller, start, upWorld);
      }
      _clearPlacement();
      return;
    }

    if (event is PointerCancelEvent) {
      final id = _placeQuadId;
      if (id != null) {
        controller.removeNode(id);
      }
      _clearPlacement();
      return;
    }
  }

  @override
  bool handleKeyEvent(KeyEvent event, InfiniteCanvasController controller) {
    if (_editingText.value != null) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        stopEditing(controller, commit: false);
        return true;
      }
      if (event is! KeyDownEvent) return false;
      if (!canvasFocusNode.hasFocus) {
        canvasFocusNode.requestFocus();
      }
      final editing = _editingText.value!;
      final value = editing.node.editingValue;
      final key = event.logicalKey;
      final expandSelection = HardwareKeyboard.instance.isShiftPressed;
      TextEditingValue? next;
      if (key == LogicalKeyboardKey.arrowLeft) {
        next = _moveHorizontal(value, true, expandSelection: expandSelection);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        next = _moveHorizontal(value, false, expandSelection: expandSelection);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        next = _moveVertical(
          value,
          editing.node,
          controller.camera,
          true,
          expandSelection: expandSelection,
        );
      } else if (key == LogicalKeyboardKey.arrowDown) {
        next = _moveVertical(
          value,
          editing.node,
          controller.camera,
          false,
          expandSelection: expandSelection,
        );
      } else if (key == LogicalKeyboardKey.backspace) {
        next = _deleteBackward(value);
      } else if (key == LogicalKeyboardKey.delete) {
        next = _deleteForward(value);
      }
      if (next != null) {
        _applyEditingValue(controller, next);
        return true;
      }
      // Let non-navigation/non-delete keys flow to IME so typed characters
      // are delivered via delta updates.
      return false;
    }
    if (tool.value == CanvasTool.select) {
      return delegate.handleKeyEvent(event, controller);
    }
    return false;
  }

  @override
  Widget wrap(
    BuildContext context,
    InfiniteCanvasController controller,
    Widget child,
  ) {
    return child;
  }
}
