import 'package:flutter/services.dart';

class CanvasTextImeClient implements DeltaTextInputClient {
  CanvasTextImeClient({
    required this.onValueChanged,
    required this.onDone,
    required this.onConnectionClosed,
  });

  final ValueChanged<TextEditingValue> onValueChanged;
  final VoidCallback onDone;
  final VoidCallback onConnectionClosed;

  TextInputConnection? _connection;
  TextEditingValue _value = const TextEditingValue();
  bool _isAttachedToIme = false;

  @override
  TextEditingValue get currentTextEditingValue => _value;

  bool get isAttached => _isAttachedToIme && (_connection?.attached ?? false);

  void attach({
    required TextInputConfiguration configuration,
    required TextEditingValue value,
  }) {
    _value = value;
    _connection = TextInput.attach(this, configuration);
    _isAttachedToIme = true;
    _connection?.setEditingState(_value);
  }

  void show() => _connection?.show();

  void updateLocalValue(TextEditingValue value) {
    _value = value;
    if (isAttached) {
      _connection?.setEditingState(_value);
    }
  }

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

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void performSelector(String selectorName) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showToolbar() {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  AutofillScope? get currentAutofillScope => null;
}
