/// Tuning knobs for [DefaultInfiniteCanvasGestureHandler].
class InfiniteCanvasGestureConfig {
  const InfiniteCanvasGestureConfig({
    this.enablePan = true,
    this.enablePinchZoom = true,
    this.enableScrollZoom = true,
    this.scrollZoomSensitivity = 0.08,
  });

  final bool enablePan;
  final bool enablePinchZoom;
  final bool enableScrollZoom;

  /// Scroll wheel zoom strength (multiplicative factor per scroll “tick”).
  final double scrollZoomSensitivity;
}
