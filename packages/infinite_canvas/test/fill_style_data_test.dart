import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

void main() {
  group('FillStyleData', () {
    test('legacy JSON without kind is solid', () {
      final f = FillStyleData.fromJson({'color': 0xFFE65100});
      expect(f.kind, FillKind.solid);
      expect(f.color.toARGB32(), 0xFFE65100);
      expect(f.stops, isEmpty);
    });

    test('round-trip solid', () {
      const original = FillStyleData(color: ui.Color(0xFF112233));
      final json = original.toJson();
      final back = FillStyleData.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(original.toJson()));
    });

    test('linear gradient round-trip', () {
      final original = FillStyleData(
        color: const ui.Color(0xFF000000),
        kind: FillKind.linearGradient,
        stops: const <GradientColorStop>[
          GradientColorStop(offset: 0, color: ui.Color(0xFFFF0000)),
          GradientColorStop(offset: 1, color: ui.Color(0xFF0000FF)),
        ],
        linearEndX: 0,
        linearEndY: 1,
      );
      final back = FillStyleData.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(back.kind, FillKind.linearGradient);
      expect(back.stops.length, 2);
      expect(back.linearEndY, 1);
    });

    test('copyWithSolidColor clears gradient', () {
      final g = FillStyleData(
        color: const ui.Color(0xFF000000),
        kind: FillKind.linearGradient,
        stops: const <GradientColorStop>[
          GradientColorStop(offset: 0, color: ui.Color(0xFFFF0000)),
        ],
      );
      final s = g.copyWithSolidColor(const ui.Color(0xFF00FF00));
      expect(s.kind, FillKind.solid);
      expect(s.stops, isEmpty);
      expect(s.color.toARGB32(), 0xFF00FF00);
    });
  });
}
