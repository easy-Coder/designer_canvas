import 'package:flutter/widgets.dart';

import '../controller/infinite_canvas_controller.dart';

/// Pluggable gesture / pointer layer around the [Repaint] canvas subtree.
abstract class InfiniteCanvasGestureHandler {
  const InfiniteCanvasGestureHandler();

  /// Returns [child] wrapped with pointer handling for [controller].
  Widget wrap(
    BuildContext context,
    InfiniteCanvasController controller,
    Widget child,
  );
}
