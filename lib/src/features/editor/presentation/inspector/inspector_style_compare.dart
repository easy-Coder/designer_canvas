import 'dart:convert';

import 'package:infinite_canvas/infinite_canvas.dart';

bool fillJsonEquals(FillStyleData a, FillStyleData b) {
  return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}

bool strokeJsonEquals(StrokeStyleData a, StrokeStyleData b) {
  return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}

bool shadowJsonEquals(ShadowStyleData a, ShadowStyleData b) {
  return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}
