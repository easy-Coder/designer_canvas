import 'dart:ui' as ui;

import 'package:infinite_canvas/infinite_canvas.dart';

enum NodeTextAlign { left, center, right }

enum NodeTextVerticalAlign { top, center, bottom }

enum NodeTextLayoutMode { autoWidthAutoHeight, fixedSize }

String _textAlignToJson(NodeTextAlign value) => value.name;

NodeTextAlign _textAlignFromJson(Object? raw) {
  final name = raw is String ? raw : NodeTextAlign.left.name;
  return NodeTextAlign.values.firstWhere(
    (v) => v.name == name,
    orElse: () => NodeTextAlign.left,
  );
}

String _textVerticalAlignToJson(NodeTextVerticalAlign value) => value.name;
String _textLayoutModeToJson(NodeTextLayoutMode value) => value.name;

NodeTextVerticalAlign _textVerticalAlignFromJson(Object? raw) {
  final name = raw is String ? raw : NodeTextVerticalAlign.top.name;
  return NodeTextVerticalAlign.values.firstWhere(
    (v) => v.name == name,
    orElse: () => NodeTextVerticalAlign.top,
  );
}

NodeTextLayoutMode _textLayoutModeFromJson(Object? raw) {
  final name = raw is String
      ? raw
      : NodeTextLayoutMode.autoWidthAutoHeight.name;
  return NodeTextLayoutMode.values.firstWhere(
    (v) => v.name == name,
    orElse: () => NodeTextLayoutMode.autoWidthAutoHeight,
  );
}

String _fontStyleToJson(ui.FontStyle value) => value.name;

ui.FontStyle _fontStyleFromJson(Object? raw) {
  final name = raw is String ? raw : ui.FontStyle.normal.name;
  return ui.FontStyle.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ui.FontStyle.normal,
  );
}

class RectNodeStyle extends NodeStyle {
  const RectNodeStyle({
    this.fill = const FillStyleData(color: ui.Color(0xFFE65100)),
    this.stroke,
    this.shadow,
    this.cornerRadius = 8,
  });

  static const String kindValue = 'rect';

  final FillStyleData fill;
  final StrokeStyleData? stroke;
  final ShadowStyleData? shadow;
  final double cornerRadius;

  @override
  String get kind => kindValue;

  @override
  RectNodeStyle copyWith({
    FillStyleData? fill,
    StrokeStyleData? stroke,
    ShadowStyleData? shadow,
    double? cornerRadius,
    bool clearStroke = false,
    bool clearShadow = false,
  }) {
    return RectNodeStyle(
      fill: fill ?? this.fill,
      stroke: clearStroke ? null : (stroke ?? this.stroke),
      shadow: clearShadow ? null : (shadow ?? this.shadow),
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'fill': fill.toJson(),
      'stroke': stroke?.toJson(),
      'shadow': shadow?.toJson(),
      'cornerRadius': cornerRadius,
    };
  }

  factory RectNodeStyle.fromJson(Map<String, dynamic> json) {
    return RectNodeStyle(
      fill: FillStyleData.fromJson(
        (json['fill'] as Map?)?.cast<String, dynamic>() ??
            {'color': 0xFFE65100},
      ),
      stroke: (json['stroke'] as Map?)?.cast<String, dynamic>().let(
        StrokeStyleData.fromJson,
      ),
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 8.0,
    );
  }
}

class FrameNodeStyle extends NodeStyle {
  const FrameNodeStyle({
    this.fill = const FillStyleData(color: ui.Color(0x14B0BEC5)),
    this.stroke = const StrokeStyleData(color: ui.Color(0xFF607D8B), width: 1),
    this.shadow,
  });

  static const String kindValue = 'frame';

  final FillStyleData fill;
  final StrokeStyleData? stroke;
  final ShadowStyleData? shadow;

  @override
  String get kind => kindValue;

  @override
  FrameNodeStyle copyWith({
    FillStyleData? fill,
    StrokeStyleData? stroke,
    ShadowStyleData? shadow,
    bool clearStroke = false,
    bool clearShadow = false,
  }) {
    return FrameNodeStyle(
      fill: fill ?? this.fill,
      stroke: clearStroke ? null : (stroke ?? this.stroke),
      shadow: clearShadow ? null : (shadow ?? this.shadow),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'fill': fill.toJson(),
      'stroke': stroke?.toJson(),
      'shadow': shadow?.toJson(),
    };
  }

  factory FrameNodeStyle.fromJson(Map<String, dynamic> json) {
    return FrameNodeStyle(
      fill: FillStyleData.fromJson(
        (json['fill'] as Map?)?.cast<String, dynamic>() ??
            {'color': 0x14B0BEC5},
      ),
      stroke: (json['stroke'] as Map?)?.cast<String, dynamic>().let(
        StrokeStyleData.fromJson,
      ),
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
    );
  }
}

class CircleNodeStyle extends NodeStyle {
  const CircleNodeStyle({
    this.fill = const FillStyleData(color: ui.Color(0xFF7B1FA2)),
    this.stroke,
    this.shadow,
  });

  static const String kindValue = 'circle';

  final FillStyleData fill;
  final StrokeStyleData? stroke;
  final ShadowStyleData? shadow;

  @override
  String get kind => kindValue;

  @override
  CircleNodeStyle copyWith({
    FillStyleData? fill,
    StrokeStyleData? stroke,
    ShadowStyleData? shadow,
    bool clearStroke = false,
    bool clearShadow = false,
  }) {
    return CircleNodeStyle(
      fill: fill ?? this.fill,
      stroke: clearStroke ? null : (stroke ?? this.stroke),
      shadow: clearShadow ? null : (shadow ?? this.shadow),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'fill': fill.toJson(),
      'stroke': stroke?.toJson(),
      'shadow': shadow?.toJson(),
    };
  }

  factory CircleNodeStyle.fromJson(Map<String, dynamic> json) {
    return CircleNodeStyle(
      fill: FillStyleData.fromJson(
        (json['fill'] as Map?)?.cast<String, dynamic>() ??
            {'color': 0xFF7B1FA2},
      ),
      stroke: (json['stroke'] as Map?)?.cast<String, dynamic>().let(
        StrokeStyleData.fromJson,
      ),
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
    );
  }
}

class PolygonNodeStyle extends NodeStyle {
  const PolygonNodeStyle({
    this.fill = const FillStyleData(color: ui.Color(0xFF00897B)),
    this.stroke,
    this.shadow,
    this.side = 3,
  });

  static const String kindValue = 'polygon';

  final FillStyleData fill;
  final StrokeStyleData? stroke;
  final ShadowStyleData? shadow;
  final int side;

  @override
  String get kind => kindValue;

  @override
  PolygonNodeStyle copyWith({
    FillStyleData? fill,
    StrokeStyleData? stroke,
    ShadowStyleData? shadow,
    bool clearStroke = false,
    bool clearShadow = false,
    int? side,
  }) {
    return PolygonNodeStyle(
      fill: fill ?? this.fill,
      stroke: clearStroke ? null : (stroke ?? this.stroke),
      shadow: clearShadow ? null : (shadow ?? this.shadow),
      side: side ?? this.side,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'fill': fill.toJson(),
      'stroke': stroke?.toJson(),
      'shadow': shadow?.toJson(),
      'side': side,
    };
  }

  factory PolygonNodeStyle.fromJson(Map<String, dynamic> json) {
    return PolygonNodeStyle(
      fill: FillStyleData.fromJson(
        (json['fill'] as Map?)?.cast<String, dynamic>() ??
            {'color': 0xFF00897B},
      ),
      stroke: (json['stroke'] as Map?)?.cast<String, dynamic>().let(
        StrokeStyleData.fromJson,
      ),
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
      side: (json['side'] as num?)?.toInt() ?? 3,
    );
  }
}

class LineNodeStyle extends NodeStyle {
  const LineNodeStyle({
    this.stroke = const StrokeStyleData(
      color: ui.Color(0xFFC62828),
      width: 3,
      cap: ui.StrokeCap.round,
      join: ui.StrokeJoin.round,
    ),
    this.shadow,
  });

  static const String kindValue = 'line';

  final StrokeStyleData stroke;
  final ShadowStyleData? shadow;

  @override
  String get kind => kindValue;

  @override
  LineNodeStyle copyWith({
    StrokeStyleData? stroke,
    ShadowStyleData? shadow,
    bool clearShadow = false,
  }) {
    return LineNodeStyle(
      stroke: stroke ?? this.stroke,
      shadow: clearShadow ? null : (shadow ?? this.shadow),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'stroke': stroke.toJson(),
      'shadow': shadow?.toJson(),
    };
  }

  factory LineNodeStyle.fromJson(Map<String, dynamic> json) {
    return LineNodeStyle(
      stroke: StrokeStyleData.fromJson(
        (json['stroke'] as Map?)?.cast<String, dynamic>() ??
            const StrokeStyleData(
              color: ui.Color(0xFFC62828),
              width: 3,
            ).toJson(),
      ),
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
    );
  }
}

class TextNodeStyle extends NodeStyle {
  const TextNodeStyle({
    this.color = const ui.Color(0xFF37474F),
    this.fontFamily,
    this.fontSize = 22,
    this.fontStyle = ui.FontStyle.normal,
    this.fontWeight = 400,
    this.textAlign = NodeTextAlign.left,
    this.verticalAlign = NodeTextVerticalAlign.top,
    this.layoutMode = NodeTextLayoutMode.autoWidthAutoHeight,
    this.fixedWidth = 240,
    this.fixedHeight = 64,
    this.backgroundColor,
    this.backgroundCornerRadius = 0,
    this.shadow,
  });

  static const String kindValue = 'text';

  final ui.Color color;
  final String? fontFamily;
  final double fontSize;
  final ui.FontStyle fontStyle;
  final int fontWeight;
  final NodeTextAlign textAlign;
  final NodeTextVerticalAlign verticalAlign;
  final NodeTextLayoutMode layoutMode;
  final double fixedWidth;
  final double fixedHeight;
  final ui.Color? backgroundColor;
  final double backgroundCornerRadius;
  final ShadowStyleData? shadow;

  @override
  String get kind => kindValue;

  @override
  TextNodeStyle copyWith({
    ui.Color? color,
    String? fontFamily,
    bool clearFontFamily = false,
    double? fontSize,
    ui.FontStyle? fontStyle,
    int? fontWeight,
    NodeTextAlign? textAlign,
    NodeTextVerticalAlign? verticalAlign,
    NodeTextLayoutMode? layoutMode,
    double? fixedWidth,
    double? fixedHeight,
    ui.Color? backgroundColor,
    bool clearBackgroundColor = false,
    double? backgroundCornerRadius,
    ShadowStyleData? shadow,
    bool clearShadow = false,
  }) {
    return TextNodeStyle(
      color: color ?? this.color,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      fontSize: fontSize ?? this.fontSize,
      fontStyle: fontStyle ?? this.fontStyle,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      layoutMode: layoutMode ?? this.layoutMode,
      fixedWidth: fixedWidth ?? this.fixedWidth,
      fixedHeight: fixedHeight ?? this.fixedHeight,
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      backgroundCornerRadius:
          backgroundCornerRadius ?? this.backgroundCornerRadius,
      shadow: clearShadow ? null : (shadow ?? this.shadow),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'color': color.toARGB32(),
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontStyle': _fontStyleToJson(fontStyle),
      'fontWeight': fontWeight,
      'textAlign': _textAlignToJson(textAlign),
      'verticalAlign': _textVerticalAlignToJson(verticalAlign),
      'layoutMode': _textLayoutModeToJson(layoutMode),
      'fixedWidth': fixedWidth,
      'fixedHeight': fixedHeight,
      'backgroundColor': backgroundColor?.toARGB32(),
      'backgroundCornerRadius': backgroundCornerRadius,
      'shadow': shadow?.toJson(),
    };
  }

  factory TextNodeStyle.fromJson(Map<String, dynamic> json) {
    return TextNodeStyle(
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0xFF37474F),
      fontFamily: json['fontFamily'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22,
      fontStyle: _fontStyleFromJson(json['fontStyle']),
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      textAlign: _textAlignFromJson(json['textAlign']),
      verticalAlign: _textVerticalAlignFromJson(json['verticalAlign']),
      layoutMode: _textLayoutModeFromJson(json['layoutMode']),
      fixedWidth: (json['fixedWidth'] as num?)?.toDouble() ?? 240,
      fixedHeight: (json['fixedHeight'] as num?)?.toDouble() ?? 64,
      backgroundColor: (json['backgroundColor'] as num?) == null
          ? null
          : ui.Color((json['backgroundColor'] as num).toInt()),
      backgroundCornerRadius:
          (json['backgroundCornerRadius'] as num?)?.toDouble() ?? 0,
      shadow: (json['shadow'] as Map?)?.cast<String, dynamic>().let(
        ShadowStyleData.fromJson,
      ),
    );
  }
}

extension _MapLet<K, V> on Map<K, V> {
  T let<T>(T Function(Map<K, V>) mapper) => mapper(this);
}
