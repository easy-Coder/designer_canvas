import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller/infinite_canvas_controller.dart';

/// Pluggable input for the infinite canvas.
///
/// **Pointers** are delivered by the `repaint` package through
/// [RePainter.onPointerEvent] on [InfiniteCanvasRepainter], which forwards to
/// [handlePointerEvent].
///
/// **Keyboard** uses [HardwareKeyboard.instance.addHandler] while the
/// [RePaint] box is mounted (see [InfiniteCanvasRepainter.mount]); handlers
/// are global to the app binding—return `false` from [handleKeyEvent] unless
/// you intentionally consume a key.
abstract class InfiniteCanvasGestureHandler {
  const InfiniteCanvasGestureHandler();

  /// Pointer events from [RePaintBox] (via `repaint` [RePainter.onPointerEvent]).
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  );

  /// Global hardware key events while the canvas repainter is mounted.
  ///
  /// Return `true` if the event was handled (see [HardwareKeyboard.addHandler]).
  bool handleKeyEvent(
    KeyEvent event,
    InfiniteCanvasController controller,
  ) =>
      false;

  /// Optional hook for apps that expose inline editing state.
  ///
  /// When non-null, painter overlays can tailor selection chrome for the
  /// currently edited node (for example, hiding transform handles).
  int? get activeEditingQuadId => null;

  /// Optional wrapper for overlays (minimap, selection chrome). Default is pass-through.
  Widget wrap(
    BuildContext context,
    InfiniteCanvasController controller,
    Widget child,
  ) =>
      child;
}

/// No-op handler used until [InfiniteCanvasView] assigns a real implementation.
final class NoopInfiniteCanvasGestureHandler extends InfiniteCanvasGestureHandler {
  const NoopInfiniteCanvasGestureHandler();

  @override
  void handlePointerEvent(
    PointerEvent event,
    InfiniteCanvasController controller,
  ) {}
}
