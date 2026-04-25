import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'node_styles.dart';

class ToolStyleDefaults {
  const ToolStyleDefaults({
    this.text = const TextNodeStyle(),
    this.frame = const FrameNodeStyle(),
    this.rect = const RectNodeStyle(),
    this.circle = const CircleNodeStyle(),
    this.triangle = const TriangleNodeStyle(),
    this.line = const LineNodeStyle(),
  });

  final TextNodeStyle text;
  final FrameNodeStyle frame;
  final RectNodeStyle rect;
  final CircleNodeStyle circle;
  final TriangleNodeStyle triangle;
  final LineNodeStyle line;

  NodeStyle styleFor(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.text => text,
      CanvasTool.frame => frame,
      CanvasTool.rect => rect,
      CanvasTool.circle => circle,
      CanvasTool.triangle => triangle,
      CanvasTool.line => line,
      CanvasTool.select => rect,
    };
  }

  ToolStyleDefaults copyWith({
    TextNodeStyle? text,
    FrameNodeStyle? frame,
    RectNodeStyle? rect,
    CircleNodeStyle? circle,
    TriangleNodeStyle? triangle,
    LineNodeStyle? line,
  }) {
    return ToolStyleDefaults(
      text: text ?? this.text,
      frame: frame ?? this.frame,
      rect: rect ?? this.rect,
      circle: circle ?? this.circle,
      triangle: triangle ?? this.triangle,
      line: line ?? this.line,
    );
  }

  ToolStyleDefaults withStyle(CanvasTool tool, NodeStyle style) {
    return switch (tool) {
      CanvasTool.text when style is TextNodeStyle => copyWith(text: style),
      CanvasTool.frame when style is FrameNodeStyle => copyWith(frame: style),
      CanvasTool.rect when style is RectNodeStyle => copyWith(rect: style),
      CanvasTool.circle when style is CircleNodeStyle => copyWith(
        circle: style,
      ),
      CanvasTool.triangle when style is TriangleNodeStyle => copyWith(
        triangle: style,
      ),
      CanvasTool.line when style is LineNodeStyle => copyWith(line: style),
      _ => this,
    };
  }
}
