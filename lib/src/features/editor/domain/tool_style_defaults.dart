import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'node_styles.dart';

class ToolStyleDefaults {
  const ToolStyleDefaults({
    this.text = const TextNodeStyle(),
    this.frame = const FrameNodeStyle(),
    this.rect = const RectNodeStyle(),
    this.circle = const CircleNodeStyle(),

    this.line = const LineNodeStyle(),
    this.polygon = const PolygonNodeStyle(),
    this.star = const RectNodeStyle(
      fill: FillStyleData(color: ui.Color(0xFFFFCA28)),
    ),
    this.image = const RectNodeStyle(
      fill: FillStyleData(color: ui.Color(0x00000000)),
      stroke: StrokeStyleData(color: ui.Color(0xFF757575), width: 1),
    ),
  });

  final TextNodeStyle text;
  final FrameNodeStyle frame;
  final RectNodeStyle rect;
  final CircleNodeStyle circle;
  final LineNodeStyle line;
  final PolygonNodeStyle polygon;
  final RectNodeStyle star;
  final RectNodeStyle image;

  NodeStyle styleFor(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.text => text,
      CanvasTool.frame => frame,
      CanvasTool.rect => rect,
      CanvasTool.circle => circle,
      CanvasTool.line || CanvasTool.pen => line,
      CanvasTool.arrow => line,
      CanvasTool.polygon => polygon,
      CanvasTool.star => star,
      CanvasTool.image => image,
      CanvasTool.select => rect,
    };
  }

  ToolStyleDefaults copyWith({
    TextNodeStyle? text,
    FrameNodeStyle? frame,
    RectNodeStyle? rect,
    CircleNodeStyle? circle,
    LineNodeStyle? line,
    PolygonNodeStyle? polygon,
    RectNodeStyle? star,
    RectNodeStyle? image,
  }) {
    return ToolStyleDefaults(
      text: text ?? this.text,
      frame: frame ?? this.frame,
      rect: rect ?? this.rect,
      circle: circle ?? this.circle,
      line: line ?? this.line,
      polygon: polygon ?? this.polygon,
      star: star ?? this.star,
      image: image ?? this.image,
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
      CanvasTool.line ||
      CanvasTool.pen ||
      CanvasTool.arrow when style is LineNodeStyle => copyWith(line: style),
      CanvasTool.polygon when style is PolygonNodeStyle => copyWith(
        polygon: style,
      ),
      CanvasTool.star when style is RectNodeStyle => copyWith(star: style),
      CanvasTool.image when style is RectNodeStyle => copyWith(image: style),
      _ => this,
    };
  }
}
