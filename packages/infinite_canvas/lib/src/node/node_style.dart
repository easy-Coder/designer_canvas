import 'dart:ui' as ui;

enum StrokePatternStyle { solid, dashed, dotted }

String _strokePatternToJson(StrokePatternStyle value) => value.name;

StrokePatternStyle _strokePatternFromJson(Object? raw) {
  final name = raw is String ? raw : StrokePatternStyle.solid.name;
  return StrokePatternStyle.values.firstWhere(
    (v) => v.name == name,
    orElse: () => StrokePatternStyle.solid,
  );
}

String _strokeCapToJson(ui.StrokeCap value) => value.name;

ui.StrokeCap _strokeCapFromJson(Object? raw) {
  final name = raw is String ? raw : ui.StrokeCap.butt.name;
  return ui.StrokeCap.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ui.StrokeCap.butt,
  );
}

String _strokeJoinToJson(ui.StrokeJoin value) => value.name;

ui.StrokeJoin _strokeJoinFromJson(Object? raw) {
  final name = raw is String ? raw : ui.StrokeJoin.miter.name;
  return ui.StrokeJoin.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ui.StrokeJoin.miter,
  );
}

class FillStyleData {
  const FillStyleData({required this.color});

  final ui.Color color;

  FillStyleData copyWith({ui.Color? color}) {
    return FillStyleData(color: color ?? this.color);
  }

  Map<String, dynamic> toJson() {
    return {'color': color.toARGB32()};
  }

  factory FillStyleData.fromJson(Map<String, dynamic> json) {
    return FillStyleData(
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0x00000000),
    );
  }
}

class StrokeStyleData {
  const StrokeStyleData({
    required this.color,
    required this.width,
    this.pattern = StrokePatternStyle.solid,
    this.dashLength = 12,
    this.dashGap = 8,
    this.cap = ui.StrokeCap.round,
    this.join = ui.StrokeJoin.round,
  });

  final ui.Color color;
  final double width;
  final StrokePatternStyle pattern;
  final double dashLength;
  final double dashGap;
  final ui.StrokeCap cap;
  final ui.StrokeJoin join;

  StrokeStyleData copyWith({
    ui.Color? color,
    double? width,
    StrokePatternStyle? pattern,
    double? dashLength,
    double? dashGap,
    ui.StrokeCap? cap,
    ui.StrokeJoin? join,
  }) {
    return StrokeStyleData(
      color: color ?? this.color,
      width: width ?? this.width,
      pattern: pattern ?? this.pattern,
      dashLength: dashLength ?? this.dashLength,
      dashGap: dashGap ?? this.dashGap,
      cap: cap ?? this.cap,
      join: join ?? this.join,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'width': width,
      'pattern': _strokePatternToJson(pattern),
      'dashLength': dashLength,
      'dashGap': dashGap,
      'cap': _strokeCapToJson(cap),
      'join': _strokeJoinToJson(join),
    };
  }

  factory StrokeStyleData.fromJson(Map<String, dynamic> json) {
    return StrokeStyleData(
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
      width: (json['width'] as num?)?.toDouble() ?? 1.0,
      pattern: _strokePatternFromJson(json['pattern']),
      dashLength: (json['dashLength'] as num?)?.toDouble() ?? 12.0,
      dashGap: (json['dashGap'] as num?)?.toDouble() ?? 8.0,
      cap: _strokeCapFromJson(json['cap']),
      join: _strokeJoinFromJson(json['join']),
    );
  }
}

class ShadowStyleData {
  const ShadowStyleData({
    required this.color,
    this.offsetX = 0,
    this.offsetY = 4,
    this.blurRadius = 10,
  });

  final ui.Color color;
  final double offsetX;
  final double offsetY;
  final double blurRadius;

  ShadowStyleData copyWith({
    ui.Color? color,
    double? offsetX,
    double? offsetY,
    double? blurRadius,
  }) {
    return ShadowStyleData(
      color: color ?? this.color,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      blurRadius: blurRadius ?? this.blurRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'offsetX': offsetX,
      'offsetY': offsetY,
      'blurRadius': blurRadius,
    };
  }

  factory ShadowStyleData.fromJson(Map<String, dynamic> json) {
    return ShadowStyleData(
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0x55000000),
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 4,
      blurRadius: (json['blurRadius'] as num?)?.toDouble() ?? 10,
    );
  }
}

abstract class NodeStyle {
  const NodeStyle();

  String get kind;

  Map<String, dynamic> toJson();

  NodeStyle copyWith();
}

class BasicNodeStyle extends NodeStyle {
  const BasicNodeStyle();

  static const String kindValue = 'basic';

  @override
  String get kind => kindValue;

  @override
  BasicNodeStyle copyWith() => const BasicNodeStyle();

  @override
  Map<String, dynamic> toJson() => const {'kind': kindValue};
}
