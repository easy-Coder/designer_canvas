/// Tuning knobs for [DefaultInfiniteCanvasGestureHandler].
class InfiniteCanvasGestureConfig {
  const InfiniteCanvasGestureConfig({
    this.enablePan = true,
    this.enablePinchZoom = true,
    this.enableScrollZoom = true,
    this.scrollZoomSensitivity = 0.08,
    this.enableKeyboardShortcuts = false,
    this.keyboardPanStepWorld = 80,
    this.keyboardZoomStep = 0.08,
  });

  final bool enablePan;
  final bool enablePinchZoom;
  final bool enableScrollZoom;

  /// Scroll wheel zoom strength (multiplicative factor per scroll “tick”).
  final double scrollZoomSensitivity;

  /// When true, [HardwareKeyboard] is used (see [InfiniteCanvasRepainter]) to
  /// apply zoom/pan shortcuts. Handlers are **global** while the canvas is
  /// mounted; keep [handleKeyEvent] fast and only return true for keys you own.
  final bool enableKeyboardShortcuts;

  /// World-space pan distance per arrow / WASD key press.
  final double keyboardPanStepWorld;

  /// Added/subtracted from [Camera.zoomDouble] per +/- key step (clamped).
  final double keyboardZoomStep;
}
