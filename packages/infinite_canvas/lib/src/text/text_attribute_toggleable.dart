/// Implemented by canvas nodes that support whole-node bold / italic / underline
/// toggles from [CanvasTextOps].
abstract interface class TextAttributeToggleable {
  void toggleBold();

  void toggleItalic();

  void toggleUnderline();
}
