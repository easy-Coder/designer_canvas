part of 'infinite_canvas_controller.dart';

/// Inline text editing: IME, caret blink, clipboard, and keyboard shortcuts.
final class CanvasTextOps {
  CanvasTextOps(this._c);

  final InfiniteCanvasController _c;

  CanvasTextImeClient? _ime;
  Timer? _blinkTimer;
  String? _editSnapshot;
  int? _editingQuadId;

  /// Undo stack for Ctrl+Z while editing (snapshots of plain text).
  final List<String> _undoStack = [];

  int? _textDragPointer;
  int? _textDragAnchorOffset;
  int _textDragMode = _kDragChar;
  int _selectionAnchorOffset = 0;
  int _textClickCount = 0;

  static const int _kDragChar = 0;
  static const int _kDragWord = 1;
  static const int _kDragLine = 2;

  int? get editingQuadId => _editingQuadId;

  CanvasNode? get editingNode =>
      _editingQuadId != null ? _c._nodesByQuadId[_editingQuadId] : null;

  TextOpsMixin? get _mixin {
    final n = editingNode;
    return n is TextOpsMixin ? n : null;
  }

  void dispose() {
    _stopBlink();
    _ime?.close();
    _ime = null;
  }

  void beginEditing(int quadId) {
    final raw = _c._nodesByQuadId[quadId];
    if (raw is! TextOpsMixin) return;
    stopEditing(commit: true);
    _undoStack.clear();
    _editSnapshot = raw.text;
    raw.beginEditing(
      selection: TextSelection.collapsed(offset: raw.text.length),
    );
    raw.caretVisible = true;
    _editingQuadId = quadId;

    _ime ??= CanvasTextImeClient(
      onValueChanged: (value) {
        final id = _editingQuadId;
        final m = _mixin;
        if (m == null || id == null) return;
        final cur = m.editingValue.text;
        if (cur != value.text) {
          _undoStack.add(cur);
          while (_undoStack.length > 60) {
            _undoStack.removeAt(0);
          }
        }
        m.applyEditingValue(value);
        m.caretVisible = true;
        _c.updateNode(id);
        _c.invalidate();
      },
      onDone: () => stopEditing(commit: true),
      onConnectionClosed: () => stopEditing(commit: true),
    );
    _ime!.attach(
      configuration: const TextInputConfiguration(
        inputType: TextInputType.multiline,
        inputAction: TextInputAction.newline,
        enableDeltaModel: true,
      ),
      value: raw.editingValue,
    );
    _ime!.show();
    _startBlink();
    _resetClickTracking();
    _c.invalidate();
  }

  void stopEditing({required bool commit}) {
    final id = _editingQuadId;
    final m = _mixin;
    if (id == null || m == null) return;

    if (!commit && _editSnapshot != null) {
      m.text = _editSnapshot!;
    } else {
      m.text = m.editingValue.text;
    }
    m.endEditing();
    _stopBlink();
    _ime?.close();
    _editSnapshot = null;
    _editingQuadId = null;
    _undoStack.clear();
    _resetClickTracking();
    _c.updateNode(id);
    _c.invalidate();
  }

  void _resetClickTracking() {
    _textDragPointer = null;
    _textDragAnchorOffset = null;
    _textDragMode = _kDragChar;
    _selectionAnchorOffset = 0;
    _textClickCount = 0;
  }

  void _startBlink() {
    _stopBlink();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      final m = _mixin;
      if (m == null) return;
      m.caretVisible = !m.caretVisible;
      _c.invalidate();
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void selectAll() {
    final m = _mixin;
    if (m == null) return;
    final t = m.editingValue.text;
    _apply(
      m.editingValue.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: t.length),
      ),
    );
  }

  void selectRange(TextSelection selection) {
    final m = _mixin;
    if (m == null) return;
    _apply(m.editingValue.copyWith(selection: selection));
  }

  void moveCaret({required bool left, bool expand = false}) {
    final m = _mixin;
    if (m == null) return;
    final next = tex.moveHorizontal(
      m.editingValue,
      left,
      expandSelection: expand,
    );
    _apply(next);
  }

  void moveCaretVertical({required bool up, bool expand = false}) {
    final m = _mixin;
    if (m == null) return;
    final tp = m.createTextPainter(_c.camera.zoomDouble, text: m.editingValue.text);
    final next = tex.moveVerticalWithPainter(
      m.editingValue,
      tp,
      up,
      expandSelection: expand,
    );
    _apply(next);
  }

  void deleteBackward() {
    final m = _mixin;
    if (m == null) return;
    _apply(tex.deleteBackward(m.editingValue));
  }

  void deleteForward() {
    final m = _mixin;
    if (m == null) return;
    _apply(tex.deleteForward(m.editingValue));
  }

  void _snapshotBeforeMutation(String previousText) {
    _undoStack.add(previousText);
    while (_undoStack.length > 60) {
      _undoStack.removeAt(0);
    }
  }

  void insertText(String text) {
    final m = _mixin;
    if (m == null) return;
    final v = m.editingValue;
    final sel = v.selection;
    if (!sel.isValid) return;
    final start = sel.start < sel.end ? sel.start : sel.end;
    final end = sel.start > sel.end ? sel.start : sel.end;
    final newText = v.text.replaceRange(start, end, text);
    _apply(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
        composing: TextRange.empty,
      ),
    );
  }

  void toggleBold() {
    switch (editingNode) {
      case final TextAttributeToggleable attrs:
        attrs.toggleBold();
        final id = _editingQuadId;
        if (id != null) _c.updateNode(id);
        _c.invalidate();
      default:
        return;
    }
  }

  void toggleItalic() {
    switch (editingNode) {
      case final TextAttributeToggleable attrs:
        attrs.toggleItalic();
        final id = _editingQuadId;
        if (id != null) _c.updateNode(id);
        _c.invalidate();
      default:
        return;
    }
  }

  void toggleUnderline() {
    switch (editingNode) {
      case final TextAttributeToggleable attrs:
        attrs.toggleUnderline();
        final id = _editingQuadId;
        if (id != null) _c.updateNode(id);
        _c.invalidate();
      default:
        return;
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final target = _undoStack.removeLast();
    _applyRaw(target);
  }

  void _applyRaw(String text) {
    final m = _mixin;
    final id = _editingQuadId;
    if (m == null || id == null) return;
    final next = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    m.applyEditingValue(next);
    m.caretVisible = true;
    _ime?.updateLocalValue(next);
    _c.updateNode(id);
    _c.invalidate();
  }

  Future<void> copy() async {
    final m = _mixin;
    if (m == null) return;
    final v = m.editingValue;
    final sel = v.selection;
    if (!sel.isValid) return;
    final a = sel.start < sel.end ? sel.start : sel.end;
    final b = sel.start > sel.end ? sel.start : sel.end;
    final slice = v.text.substring(a, b);
    if (slice.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: slice));
  }

  Future<void> cut() async {
    final m = _mixin;
    if (m == null) return;
    final v = m.editingValue;
    final sel = v.selection;
    if (!sel.isValid) return;
    final a = sel.start < sel.end ? sel.start : sel.end;
    final b = sel.start > sel.end ? sel.start : sel.end;
    final slice = v.text.substring(a, b);
    if (slice.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: slice));
    }
    if (!sel.isCollapsed) {
      _apply(tex.deleteSelection(v));
    } else {
      _apply(tex.deleteBackward(v));
    }
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || t.isEmpty) return;
    insertText(t);
  }

  void _apply(TextEditingValue next) {
    final m = _mixin;
    final id = _editingQuadId;
    if (m == null || id == null) return;
    final cur = m.editingValue.text;
    if (cur != next.text) {
      _snapshotBeforeMutation(cur);
    }
    m.applyEditingValue(next);
    m.caretVisible = true;
    _ime?.updateLocalValue(next);
    _c.updateNode(id);
    _c.invalidate();
  }

  /// [isRepeatedClick] true when this down follows a recent prior down at same spot (double/triple click).
  void selectAtViewportOffset(
    ui.Offset viewportOffset, {
    required bool shiftExtend,
    required bool isRepeatedClick,
    required CameraView camera,
    int pointer = 0,
  }) {
    final m = _mixin;
    if (m == null) return;
    final position = m.positionForViewportOffset(viewportOffset, camera);
    final offset = position.offset;

    _textClickCount =
        isRepeatedClick ? (_textClickCount + 1).clamp(1, 4) : 1;

    final current = m.editingValue.selection;
    late final TextSelection selection;
    late final int dragMode;
    late final int anchor;

    if (shiftExtend && _textClickCount == 1) {
      anchor = current.isValid ? current.baseOffset : _selectionAnchorOffset;
      selection = TextSelection(baseOffset: anchor, extentOffset: offset);
      dragMode = _kDragChar;
    } else if (_textClickCount == 2) {
      final start = tex.wordStart(m.editingValue.text, offset);
      final end = tex.wordEnd(m.editingValue.text, offset);
      selection = TextSelection(baseOffset: start, extentOffset: end);
      anchor = start;
      dragMode = _kDragWord;
    } else if (_textClickCount == 3) {
      final paintText = m.editingValue.text;
      final painter = m.createTextPainter(camera.zoomDouble, text: paintText);
      selection = tex.lineSelectionAtOffsetWithPainter(
        painter,
        paintText,
        offset,
      );
      anchor = selection.baseOffset;
      dragMode = _kDragLine;
    } else if (_textClickCount >= 4) {
      selection = TextSelection(
        baseOffset: 0,
        extentOffset: m.editingValue.text.length,
      );
      anchor = 0;
      dragMode = _kDragChar;
    } else {
      selection = TextSelection.collapsed(offset: offset);
      anchor = offset;
      dragMode = _kDragChar;
    }

    _textDragPointer = pointer;
    _textDragAnchorOffset = anchor;
    _selectionAnchorOffset = anchor;
    _textDragMode = dragMode;

    _apply(m.editingValue.copyWith(selection: selection));
  }

  /// Whether [pointer] is dragging the text selection started by [selectAtViewportOffset].
  bool isDraggingWithPointer(int pointer) => _textDragPointer == pointer;

  void dragSelectTo(ui.Offset viewportOffset, {required CameraView camera}) {
    final m = _mixin;
    if (m == null) return;
    final anchor =
        _textDragAnchorOffset ?? m.editingValue.selection.baseOffset;
    final position = m.positionForViewportOffset(viewportOffset, camera);
    final extentOffset = position.offset;
    final nextSelection = switch (_textDragMode) {
      _kDragWord => extentOffset >= anchor
          ? TextSelection(
              baseOffset: tex.wordStart(m.editingValue.text, anchor),
              extentOffset: tex.wordEnd(m.editingValue.text, extentOffset),
            )
          : TextSelection(
              baseOffset: tex.wordEnd(m.editingValue.text, anchor),
              extentOffset: tex.wordStart(m.editingValue.text, extentOffset),
            ),
      _kDragLine => () {
          final paintText = m.editingValue.text;
          final painter = m.createTextPainter(
            camera.zoomDouble,
            text: paintText,
          );
          final atAnchor = tex.lineSelectionAtOffsetWithPainter(
            painter,
            paintText,
            anchor,
          );
          final atExtent = tex.lineSelectionAtOffsetWithPainter(
            painter,
            paintText,
            extentOffset,
          );
          return TextSelection(
            baseOffset: atAnchor.baseOffset,
            extentOffset: atExtent.extentOffset,
          );
        }(),
      _ => TextSelection(baseOffset: anchor, extentOffset: extentOffset),
    };
    _apply(m.editingValue.copyWith(selection: nextSelection));
  }

  void endTextDrag() {
    _textDragPointer = null;
    _textDragAnchorOffset = null;
    _textDragMode = _kDragChar;
  }

  /// Returns true if the event was consumed (caller should not propagate).
  bool handleKeyEvent(KeyEvent event, HardwareKeyboard hw) {
    if (_editingQuadId == null) return false;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      stopEditing(commit: false);
      return true;
    }
    if (event is! KeyDownEvent) return false;

    final metaOrCtrl = hw.isMetaPressed || hw.isControlPressed;
    final shift = hw.isShiftPressed;
    final key = event.logicalKey;

    if (metaOrCtrl && key == LogicalKeyboardKey.keyA) {
      selectAll();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyZ && !shift) {
      undo();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyC) {
      copy();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyX) {
      cut();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyV) {
      paste();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyB) {
      toggleBold();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyI) {
      toggleItalic();
      return true;
    }
    if (metaOrCtrl && key == LogicalKeyboardKey.keyU) {
      toggleUnderline();
      return true;
    }

    final m = _mixin;
    if (m == null) return false;
    final value = m.editingValue;
    TextEditingValue? next;

    if (key == LogicalKeyboardKey.arrowLeft) {
      next = tex.moveHorizontal(value, true, expandSelection: shift);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      next = tex.moveHorizontal(value, false, expandSelection: shift);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final tp = m.createTextPainter(_c.camera.zoomDouble, text: value.text);
      next = tex.moveVerticalWithPainter(
        value,
        tp,
        true,
        expandSelection: shift,
      );
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final tp = m.createTextPainter(_c.camera.zoomDouble, text: value.text);
      next = tex.moveVerticalWithPainter(
        value,
        tp,
        false,
        expandSelection: shift,
      );
    } else if (key == LogicalKeyboardKey.backspace) {
      next = tex.deleteBackward(value);
    } else if (key == LogicalKeyboardKey.delete) {
      next = tex.deleteForward(value);
    }

    if (next != null) {
      _apply(next);
      return true;
    }

    // Fallback only when the IME is not delivering characters (e.g. headless
    // tests, platforms without text input, or transient connection loss).
    if (!hw.isMetaPressed && !hw.isControlPressed && !hw.isAltPressed) {
      final ch = event.character;
      final imeAlive = _ime != null && _ime!.isAttached;
      if (!imeAlive &&
          ch != null &&
          ch.isNotEmpty &&
          ch.codeUnitAt(0) >= 0x20) {
        insertText(ch);
        return true;
      }
    }

    return false;
  }
}
