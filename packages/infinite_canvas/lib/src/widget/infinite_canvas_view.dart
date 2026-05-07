import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';

import '../controller/infinite_canvas_controller.dart';
import '../painter/infinite_canvas_repainter.dart';

/// High-performance infinite canvas: [RePaint] + optional pointer forwarding.
///
/// The [controller] instance must stay stable for the lifetime of this widget
/// subtree (typical pattern: create the controller in a [State] object).
///
/// Route pointer events by setting [onPointerEvent]; keyboard handling should be
/// done by wrapping this widget in [Focus] (or similar) at the app level.
class InfiniteCanvasView extends StatefulWidget {
  const InfiniteCanvasView({
    super.key,
    required this.controller,
    this.onPointerEvent,
    this.repaintBoundary = true,
  });

  final InfiniteCanvasController controller;

  /// Receives pointer events from the `repaint` [RePaintBox].
  final void Function(PointerEvent event)? onPointerEvent;

  final bool repaintBoundary;

  @override
  State<InfiniteCanvasView> createState() => _InfiniteCanvasViewState();
}

class _InfiniteCanvasViewState extends State<InfiniteCanvasView> {
  late final InfiniteCanvasRepainter _repainter =
      InfiniteCanvasRepainter(widget.controller);

  @override
  Widget build(BuildContext context) {
    _repainter.pointerCallback = widget.onPointerEvent;
    final repaint = RePaint(
      painter: _repainter,
      repaintBoundary: widget.repaintBoundary,
    );
    return MouseRegion(
      onExit: (_) => widget.controller.clearHover(),
      child: repaint,
    );
  }
}
