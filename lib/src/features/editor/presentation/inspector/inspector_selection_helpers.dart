import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/nodes/circle_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/image_placeholder_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/star_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';

/// Whether this node type has a vector (or text) fill in the inspector.
bool nodeSupportsFill(CanvasNode n) {
  return n is RectNode ||
      n is FrameNode ||
      n is CircleNode ||
      n is PolygonNode ||
      n is StarNode ||
      n is ImageNode ||
      n is TextNode;
}

FillStyleData? readFill(CanvasNode n) {
  if (n is RectNode) return n.rectStyle.fill;
  if (n is FrameNode) return n.frameStyle.fill;
  if (n is CircleNode) return n.circleStyle.fill;
  if (n is PolygonNode) return n.polyStyle.fill;
  if (n is StarNode) return n.starStyle.fill;
  if (n is ImageNode) return n.imageStyle.fill;
  if (n is TextNode) {
    return FillStyleData(color: n.textStyle.color, kind: FillKind.solid);
  }
  return null;
}

void applyFill(CanvasNode n, FillStyleData f) {
  if (n is TextNode) {
    if (f.kind != FillKind.solid) return;
    n.style = n.textStyle.copyWith(color: f.swatchColor);
    return;
  }
  if (n is RectNode) n.style = n.rectStyle.copyWith(fill: f);
  if (n is FrameNode) n.style = n.frameStyle.copyWith(fill: f);
  if (n is CircleNode) n.style = n.circleStyle.copyWith(fill: f);
  if (n is PolygonNode) n.style = n.polyStyle.copyWith(fill: f);
  if (n is StarNode) n.style = n.starStyle.copyWith(fill: f);
  if (n is ImageNode) n.style = n.imageStyle.copyWith(fill: f);
}

StrokeStyleData? readStroke(CanvasNode n) {
  if (n is RectNode) return n.rectStyle.stroke;
  if (n is FrameNode) return n.frameStyle.stroke;
  if (n is CircleNode) return n.circleStyle.stroke;
  if (n is PolygonNode) return n.polyStyle.stroke;
  if (n is StarNode) return n.starStyle.stroke;
  if (n is ImageNode) return n.imageStyle.stroke;
  if (n is LineNode) return n.lineStyle.stroke;
  return null;
}

void applyStroke(CanvasNode n, StrokeStyleData? s) {
  if (n is RectNode) {
    n.style = n.rectStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is FrameNode) {
    n.style = n.frameStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is CircleNode) {
    n.style = n.circleStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is PolygonNode) {
    n.style = n.polyStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is StarNode) {
    n.style = n.starStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is ImageNode) {
    n.style = n.imageStyle.copyWith(stroke: s, clearStroke: s == null);
  }
  if (n is LineNode && s != null) {
    n.style = n.lineStyle.copyWith(stroke: s);
  }
}

ShadowStyleData? readShadow(CanvasNode n) {
  if (n is RectNode) return n.rectStyle.shadow;
  if (n is FrameNode) return n.frameStyle.shadow;
  if (n is CircleNode) return n.circleStyle.shadow;
  if (n is PolygonNode) return n.polyStyle.shadow;
  if (n is StarNode) return n.starStyle.shadow;
  if (n is ImageNode) return n.imageStyle.shadow;
  if (n is LineNode) return n.lineStyle.shadow;
  if (n is TextNode) return n.textStyle.shadow;
  return null;
}

void applyShadow(CanvasNode n, ShadowStyleData? s) {
  if (n is RectNode) {
    n.style = n.rectStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is FrameNode) {
    n.style = n.frameStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is CircleNode) {
    n.style = n.circleStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is PolygonNode) {
    n.style = n.polyStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is StarNode) {
    n.style = n.starStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is ImageNode) {
    n.style = n.imageStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is LineNode) {
    n.style = n.lineStyle.copyWith(shadow: s, clearShadow: s == null);
  }
  if (n is TextNode) {
    n.style = n.textStyle.copyWith(shadow: s, clearShadow: s == null);
  }
}

double? readCornerRadius(CanvasNode n) {
  if (n is RectNode) return n.rectStyle.cornerRadius;
  if (n is StarNode) return n.starStyle.cornerRadius;
  if (n is TextNode) return n.textStyle.backgroundCornerRadius;
  return null;
}

void applyCornerRadius(CanvasNode n, double r) {
  if (n is RectNode) n.style = n.rectStyle.copyWith(cornerRadius: r);
  if (n is StarNode) n.style = n.starStyle.copyWith(cornerRadius: r);
  if (n is TextNode) {
    n.style = n.textStyle.copyWith(backgroundCornerRadius: r);
  }
}

bool nodeSupportsCornerRadius(CanvasNode n) =>
    n is RectNode || n is StarNode || n is TextNode;

bool nodeSupportsLayout(CanvasNode n) =>
    n is RectNode ||
    n is FrameNode ||
    n is CircleNode ||
    n is PolygonNode ||
    n is StarNode ||
    n is ImageNode ||
    n is TextNode ||
    n is LineNode;
