/// Tuning knobs for [DefaultInfiniteCanvasGestureHandler].
class InfiniteCanvasGestureConfig {
  const InfiniteCanvasGestureConfig({
    this.enableSelection = false,
    this.selectionSlopPixels = 4.0,
    this.doubleClickTimeout = const Duration(milliseconds: 350),
    this.enablePan = true,
    this.enablePinchZoom = true,
    this.middleMousePan = true,
    this.enableWheelVerticalPan = true,
    this.enableShiftWheelHorizontalPan = true,
    this.enableMetaOrControlWheelZoom = true,
    this.wheelVerticalSensitivity = 1.0,
    this.wheelHorizontalSensitivity = 1.0,
    this.wheelZoomSensitivity = 0.08,
    this.enableKeyboardShortcuts = false,
    this.keyboardPanStepWorld = 80,
    this.keyboardZoomStep = 0.08,
    this.enableNodeTransform = true,
    this.minUnionSizeWorld = 4.0,
  });

  /// When true, primary pointer selects / deselects / marquees on empty canvas;
  /// primary no longer pans the camera (use wheel, MMB, pinch).
  final bool enableSelection;

  /// Maximum movement for a click vs drag (viewport pixels).
  final double selectionSlopPixels;

  /// Double-click detection window for [InfiniteCanvasController.onNodeDoubleClick].
  final Duration doubleClickTimeout;

  final bool enablePan;
  final bool enablePinchZoom;

  /// Middle mouse drag pans the camera.
  final bool middleMousePan;

  /// Plain wheel pans vertically in world space.
  final bool enableWheelVerticalPan;

  /// Shift + wheel pans horizontally.
  final bool enableShiftWheelHorizontalPan;

  /// Meta or Control + wheel zooms at cursor.
  final bool enableMetaOrControlWheelZoom;

  /// Scales world pan from wheel `dy` (plain vertical pan).
  final double wheelVerticalSensitivity;

  /// Scales world pan from wheel deltas (shift horizontal).
  final double wheelHorizontalSensitivity;

  /// Zoom step multiplier for meta/control + wheel.
  final double wheelZoomSensitivity;

  /// When true, [HardwareKeyboard] is used (see [InfiniteCanvasRepainter]) to
  /// apply zoom/pan shortcuts. Handlers are **global** while the canvas is
  /// mounted; keep [handleKeyEvent] fast and only return true for keys you own.
  final bool enableKeyboardShortcuts;

  /// World-space pan distance per arrow / WASD key press.
  final double keyboardPanStepWorld;

  /// Added/subtracted from [Camera.zoomDouble] per +/- key step (clamped).
  final double keyboardZoomStep;

  /// When true with [enableSelection], dragging nodes and transform handles
  /// mutates node geometry ([CanvasNode.translateWorld], etc.).
  final bool enableNodeTransform;

  /// Minimum width/height of the selection union during handle resize (world).
  final double minUnionSizeWorld;
}
