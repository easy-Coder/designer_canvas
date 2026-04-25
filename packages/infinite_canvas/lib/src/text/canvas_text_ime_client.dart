/// IME plumbing for canvas-based text editors.
///
/// [CanvasTextImeClient] is a thin [DeltaTextInputClient] adapter that owns a
/// single [TextInputConnection] and forwards delta-based edits to a callback,
/// without any assumption about what the host app uses to *store* the text.
/// Pair it with the helpers in `canvas_text_ops.dart` to build a custom
/// in-canvas text editor on top of [TextPainter].
///
/// ## Lifecycle
///
/// 1. Construct with three callbacks: `onValueChanged`, `onDone`,
///    `onConnectionClosed`.
/// 2. Call [CanvasTextImeClient.attach] when editing begins, passing the
///    desired [TextInputConfiguration] and the initial [TextEditingValue].
/// 3. Call [CanvasTextImeClient.show] to raise the soft keyboard / IME panel.
/// 4. While editing, push synthetic edits (e.g. arrow-key navigation results
///    from `canvas_text_ops`) back to the IME via [CanvasTextImeClient.updateLocalValue]
///    so the composing region stays in sync.
/// 5. Call [CanvasTextImeClient.close] when editing ends (commit or cancel).
///
/// ## Example
///
/// ```dart
/// final ime = CanvasTextImeClient(
///   onValueChanged: (v) => myNode.applyEditingValue(v),
///   onDone: () => stopEditing(commit: true),
///   onConnectionClosed: () => stopEditing(commit: true),
/// );
/// ime.attach(
///   configuration: const TextInputConfiguration(
///     inputType: TextInputType.multiline,
///     enableDeltaModel: true,
///   ),
///   value: myNode.editingValue,
/// );
/// ime.show();
/// ```
library;

import 'package:flutter/services.dart';

/// Bridges the platform IME to a host that stores a [TextEditingValue] itself
/// (typical for canvas text: no [EditableText] widget in the tree).
class CanvasTextImeClient implements DeltaTextInputClient {
  /// [onValueChanged] receives every IME-driven update (deltas or full value).
  ///
  /// [onDone] runs when the user commits an action such as Done / Go / Send /
  /// Search on the keyboard (not newline — that is usually delivered as text).
  ///
  /// [onConnectionClosed] runs when the platform tears down the connection;
  /// treat it like an implicit end of editing.
  CanvasTextImeClient({
    required this.onValueChanged,
    required this.onDone,
    required this.onConnectionClosed,
  });

  /// Called after each successful IME edit so the host can persist [value].
  final ValueChanged<TextEditingValue> onValueChanged;

  /// Called when the IME signals a primary "submit" style action.
  final VoidCallback onDone;

  /// Called when [TextInputConnection.close] happens from the platform side.
  final VoidCallback onConnectionClosed;

  TextInputConnection? _connection;
  TextEditingValue _value = const TextEditingValue();
  bool _isAttachedToIme = false;

  @override
  TextEditingValue get currentTextEditingValue => _value;

  /// Whether [attach] ran and the underlying connection is still attached.
  bool get isAttached => _isAttachedToIme && (_connection?.attached ?? false);

  /// Opens a new [TextInputConnection] for this client and seeds platform state.
  ///
  /// Call [close] before [attach] again if reusing the same instance.
  void attach({
    required TextInputConfiguration configuration,
    required TextEditingValue value,
  }) {
    _value = value;
    _connection = TextInput.attach(this, configuration);
    _isAttachedToIme = true;
    _connection?.setEditingState(_value);
  }

  /// Shows the soft keyboard when a connection exists.
  void show() => _connection?.show();

  /// Updates the in-memory value and mirrors it to the IME when attached.
  ///
  /// Use this after local edits (arrow keys, programmatic selection changes)
  /// so the IME's composing range matches your [TextEditingValue].
  void updateLocalValue(TextEditingValue value) {
    _value = value;
    if (isAttached) {
      _connection?.setEditingState(_value);
    }
  }

  /// Closes the connection and clears internal attachment state.
  void close() {
    _connection?.close();
    _connection = null;
    _isAttachedToIme = false;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    for (final delta in textEditingDeltas) {
      _value = delta.apply(_value);
      onValueChanged(_value);
      if (isAttached) {
        _connection?.setEditingState(_value);
      }
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _value = value;
    onValueChanged(_value);
    if (isAttached) {
      _connection?.setEditingState(_value);
    }
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.done ||
        action == TextInputAction.go ||
        action == TextInputAction.send ||
        action == TextInputAction.search) {
      onDone();
    }
  }

  @override
  void connectionClosed() {
    _connection = null;
    _isAttachedToIme = false;
    onConnectionClosed();
  }

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void performSelector(String selectorName) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void insertContent(KeyboardInsertedContent content) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void insertTextPlaceholder(Size size) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void removeTextPlaceholder() {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void showToolbar() {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  /// Not used for canvas editors; no-op for [DeltaTextInputClient] contract.
  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  /// Canvas editors do not participate in autofill scopes.
  @override
  AutofillScope? get currentAutofillScope => null;
}
