import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../controller/infinite_canvas_controller.dart';
import '../gesture/default_infinite_canvas_gesture_handler.dart';
import '../gesture/infinite_canvas_gesture_config.dart';
import '../gesture/infinite_canvas_gesture_handler.dart';
import '../painter/infinite_canvas_repainter.dart';

/// High-performance infinite canvas: [RePaint] + pluggable gestures.
///
/// The [controller] instance must stay stable for the lifetime of this widget
/// subtree (typical pattern: create the controller in a [State] object).
///
/// Input is routed through the `repaint` [RePainter]: pointers via
/// [RePainter.onPointerEvent], and keyboard via [HardwareKeyboard] while the
/// repainter is mounted (see [InfiniteCanvasRepainter]).
class InfiniteCanvasView extends StatefulWidget {
  const InfiniteCanvasView({
    super.key,
    required this.controller,
    this.gestureHandler,
    this.gestureConfig = const InfiniteCanvasGestureConfig(),
    this.repaintBoundary = true,
  });

  final InfiniteCanvasController controller;

  /// When null, [DefaultInfiniteCanvasGestureHandler] is used with
  /// [gestureConfig].
  final InfiniteCanvasGestureHandler? gestureHandler;

  final InfiniteCanvasGestureConfig gestureConfig;

  final bool repaintBoundary;

  @override
  State<InfiniteCanvasView> createState() => _InfiniteCanvasViewState();
}

class _InfiniteCanvasViewState extends State<InfiniteCanvasView> {
  late final InfiniteCanvasRepainter _repainter =
      InfiniteCanvasRepainter(widget.controller);

  @override
  Widget build(BuildContext context) {
    final handler = widget.gestureHandler ??
        DefaultInfiniteCanvasGestureHandler(config: widget.gestureConfig);
    _repainter.gestureHandler = handler;
    final repaint = RePaint(
      painter: _repainter,
      repaintBoundary: widget.repaintBoundary,
    );
    final canvas = handler.wrap(context, widget.controller, repaint);
    return MouseRegion(
      onExit: (_) => widget.controller.clearHover(),
      child: canvas,
    );
  }
}
