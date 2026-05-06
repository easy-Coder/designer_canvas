import 'dart:ui' as ui;

String fillHexRgb(ui.Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return v.toRadixString(16).toUpperCase().padLeft(6, '0');
}

ui.Color? tryParseHexRgb(String raw) {
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return ui.Color(0xFF000000 | v);
  }
  return null;
}

int alpha255(ui.Color c) => (c.a * 255.0).round().clamp(0, 255);
