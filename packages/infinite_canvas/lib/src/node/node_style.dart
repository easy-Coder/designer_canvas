import 'dart:ui' as ui;

enum FillKind { solid, linearGradient, radialGradient, image }

String _fillKindToJson(FillKind value) => value.name;

FillKind _fillKindFromJson(Object? raw) {
  final name = raw is String ? raw : FillKind.solid.name;
  return FillKind.values.firstWhere(
    (v) => v.name == name,
    orElse: () => FillKind.solid,
  );
}

enum FillImageFit { cover, contain, fill, tile }

String _fillImageFitToJson(FillImageFit value) => value.name;

FillImageFit _fillImageFitFromJson(Object? raw) {
  final name = raw is String ? raw : FillImageFit.cover.name;
  return FillImageFit.values.firstWhere(
    (v) => v.name == name,
    orElse: () => FillImageFit.cover,
  );
}

/// One stop in a vector gradient (offset in 0–1 along the gradient axis).
class GradientColorStop {
  const GradientColorStop({required this.offset, required this.color});

  final double offset;
  final ui.Color color;

  GradientColorStop copyWith({double? offset, ui.Color? color}) {
    return GradientColorStop(
      offset: offset ?? this.offset,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {'offset': offset, 'color': color.toARGB32()};
  }

  factory GradientColorStop.fromJson(Map<String, dynamic> json) {
    return GradientColorStop(
      offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
    );
  }
}

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

/// Fill appearance for vector shapes: solid color, gradients, or image.
///
/// Legacy JSON with only `color` is read as [FillKind.solid]. The [color] field
/// is always defined; for non-solid fills it is a fallback and for UI swatches
/// use [swatchColor].
class FillStyleData {
  const FillStyleData({
    required this.color,
    this.kind = FillKind.solid,
    this.stops = const <GradientColorStop>[],
    this.linearStartX = 0.0,
    this.linearStartY = 0.0,
    this.linearEndX = 1.0,
    this.linearEndY = 0.0,
    this.radialCenterX = 0.5,
    this.radialCenterY = 0.5,
    this.radialRadius = 0.5,
    this.imagePath,
    this.imageFit = FillImageFit.cover,
  });

  final FillKind kind;
  final ui.Color color;
  final List<GradientColorStop> stops;

  /// Normalized 0–1 endpoints in the fill box (see painters): linear axis.
  final double linearStartX;
  final double linearStartY;
  final double linearEndX;
  final double linearEndY;

  /// Normalized 0–1 center and radius relative to min(width, height)/2.
  final double radialCenterX;
  final double radialCenterY;
  final double radialRadius;

  final String? imagePath;
  final FillImageFit imageFit;

  /// Representative color for palettes and legacy [color] getters on nodes.
  ui.Color get swatchColor {
    switch (kind) {
      case FillKind.solid:
        return color;
      case FillKind.linearGradient:
      case FillKind.radialGradient:
        if (stops.isEmpty) return color;
        return stops.first.color;
      case FillKind.image:
        return color;
    }
  }

  List<GradientColorStop> get effectiveStops {
    if (stops.isNotEmpty) return stops;
    return <GradientColorStop>[
      GradientColorStop(offset: 0, color: color),
      GradientColorStop(offset: 1, color: color),
    ];
  }

  FillStyleData copyWith({
    ui.Color? color,
    FillKind? kind,
    List<GradientColorStop>? stops,
    double? linearStartX,
    double? linearStartY,
    double? linearEndX,
    double? linearEndY,
    double? radialCenterX,
    double? radialCenterY,
    double? radialRadius,
    String? imagePath,
    FillImageFit? imageFit,
    bool clearImagePath = false,
  }) {
    final nextKind = kind ?? this.kind;
    var nextColor = color ?? this.color;
    var nextStops = stops ?? this.stops;

    if (color != null &&
        kind == null &&
        (this.kind == FillKind.linearGradient ||
            this.kind == FillKind.radialGradient)) {
      final src = nextStops.isNotEmpty ? nextStops : effectiveStops;
      nextStops = src
          .map(
            (GradientColorStop s) => GradientColorStop(
              offset: s.offset,
              color: s.color.withAlpha((color.a * 255.0).round().clamp(0, 255)),
            ),
          )
          .toList(growable: false);
      nextColor = color;
    }

    if (nextKind == FillKind.solid) {
      return FillStyleData(
        color: nextColor,
        kind: FillKind.solid,
        stops: const <GradientColorStop>[],
        linearStartX: linearStartX ?? this.linearStartX,
        linearStartY: linearStartY ?? this.linearStartY,
        linearEndX: linearEndX ?? this.linearEndX,
        linearEndY: linearEndY ?? this.linearEndY,
        radialCenterX: radialCenterX ?? this.radialCenterX,
        radialCenterY: radialCenterY ?? this.radialCenterY,
        radialRadius: radialRadius ?? this.radialRadius,
        imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
        imageFit: imageFit ?? this.imageFit,
      );
    }

    return FillStyleData(
      color: nextColor,
      kind: nextKind,
      stops: nextStops,
      linearStartX: linearStartX ?? this.linearStartX,
      linearStartY: linearStartY ?? this.linearStartY,
      linearEndX: linearEndX ?? this.linearEndX,
      linearEndY: linearEndY ?? this.linearEndY,
      radialCenterX: radialCenterX ?? this.radialCenterX,
      radialCenterY: radialCenterY ?? this.radialCenterY,
      radialRadius: radialRadius ?? this.radialRadius,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageFit: imageFit ?? this.imageFit,
    );
  }

  /// When the user sets a single color on a node, non-solid fills become solid.
  FillStyleData copyWithSolidColor(ui.Color value) {
    return FillStyleData(
      color: value,
      kind: FillKind.solid,
      stops: const <GradientColorStop>[],
      linearStartX: linearStartX,
      linearStartY: linearStartY,
      linearEndX: linearEndX,
      linearEndY: linearEndY,
      radialCenterX: radialCenterX,
      radialCenterY: radialCenterY,
      radialRadius: radialRadius,
      imagePath: null,
      imageFit: imageFit,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'kind': _fillKindToJson(kind),
      'color': color.toARGB32(),
    };
    if (kind != FillKind.solid || stops.isNotEmpty) {
      map['stops'] = stops.map((e) => e.toJson()).toList(growable: false);
    }
    if (kind == FillKind.linearGradient) {
      map['linearStartX'] = linearStartX;
      map['linearStartY'] = linearStartY;
      map['linearEndX'] = linearEndX;
      map['linearEndY'] = linearEndY;
    }
    if (kind == FillKind.radialGradient) {
      map['radialCenterX'] = radialCenterX;
      map['radialCenterY'] = radialCenterY;
      map['radialRadius'] = radialRadius;
    }
    if (kind == FillKind.image) {
      map['imagePath'] = imagePath;
      map['imageFit'] = _fillImageFitToJson(imageFit);
    }
    return map;
  }

  factory FillStyleData.fromJson(Map<String, dynamic> json) {
    final hasKind = json.containsKey('kind');
    final kind = hasKind
        ? _fillKindFromJson(json['kind'])
        : FillKind.solid;
    final baseColor = ui.Color((json['color'] as num?)?.toInt() ?? 0x00000000);
    final stopsRaw = json['stops'] as List?;
    final stops = stopsRaw == null
        ? const <GradientColorStop>[]
        : stopsRaw
            .whereType<Map>()
            .map(
              (e) => GradientColorStop.fromJson(e.cast<String, dynamic>()),
            )
            .toList(growable: false);
    return FillStyleData(
      color: baseColor,
      kind: kind,
      stops: stops,
      linearStartX: (json['linearStartX'] as num?)?.toDouble() ?? 0.0,
      linearStartY: (json['linearStartY'] as num?)?.toDouble() ?? 0.0,
      linearEndX: (json['linearEndX'] as num?)?.toDouble() ?? 1.0,
      linearEndY: (json['linearEndY'] as num?)?.toDouble() ?? 0.0,
      radialCenterX: (json['radialCenterX'] as num?)?.toDouble() ?? 0.5,
      radialCenterY: (json['radialCenterY'] as num?)?.toDouble() ?? 0.5,
      radialRadius: (json['radialRadius'] as num?)?.toDouble() ?? 0.5,
      imagePath: json['imagePath'] as String?,
      imageFit: _fillImageFitFromJson(json['imageFit']),
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
