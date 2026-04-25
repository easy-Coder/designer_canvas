import 'dart:ui' as ui;

typedef NodeId = String;

enum NodeEntityType { rect, frame, circle, triangle, line, text }

NodeEntityType nodeEntityTypeFromName(String raw) {
  return NodeEntityType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => NodeEntityType.rect,
  );
}

class NodeVersion {
  const NodeVersion({
    this.actorId,
    this.seq = 0,
    this.lamport = 0,
    this.updatedAtEpochMs,
  });

  final String? actorId;
  final int seq;
  final int lamport;
  final int? updatedAtEpochMs;

  Map<String, dynamic> toJson() {
    return {
      'actorId': actorId,
      'seq': seq,
      'lamport': lamport,
      'updatedAtEpochMs': updatedAtEpochMs,
    };
  }

  factory NodeVersion.fromJson(Map<String, dynamic> json) {
    return NodeVersion(
      actorId: json['actorId'] as String?,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      lamport: (json['lamport'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt(),
    );
  }

  NodeVersion copyWith({
    String? actorId,
    int? seq,
    int? lamport,
    int? updatedAtEpochMs,
  }) {
    return NodeVersion(
      actorId: actorId ?? this.actorId,
      seq: seq ?? this.seq,
      lamport: lamport ?? this.lamport,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }
}

class NodeTransformData {
  const NodeTransformData({
    required this.pivotX,
    required this.pivotY,
    required this.rotationRadians,
  });

  final double pivotX;
  final double pivotY;
  final double rotationRadians;

  ui.Offset get pivot => ui.Offset(pivotX, pivotY);

  Map<String, dynamic> toJson() {
    return {
      'pivotX': pivotX,
      'pivotY': pivotY,
      'rotationRadians': rotationRadians,
    };
  }

  factory NodeTransformData.fromJson(Map<String, dynamic> json) {
    return NodeTransformData(
      pivotX: (json['pivotX'] as num?)?.toDouble() ?? 0,
      pivotY: (json['pivotY'] as num?)?.toDouble() ?? 0,
      rotationRadians: (json['rotationRadians'] as num?)?.toDouble() ?? 0,
    );
  }

  NodeTransformData copyWith({
    double? pivotX,
    double? pivotY,
    double? rotationRadians,
  }) {
    return NodeTransformData(
      pivotX: pivotX ?? this.pivotX,
      pivotY: pivotY ?? this.pivotY,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }
}

class NodeContainmentData {
  const NodeContainmentData({
    required this.localPivotX,
    required this.localPivotY,
  });

  final double localPivotX;
  final double localPivotY;

  ui.Offset get localPivot => ui.Offset(localPivotX, localPivotY);

  Map<String, dynamic> toJson() {
    return {'localPivotX': localPivotX, 'localPivotY': localPivotY};
  }

  factory NodeContainmentData.fromJson(Map<String, dynamic> json) {
    return NodeContainmentData(
      localPivotX: (json['localPivotX'] as num?)?.toDouble() ?? 0,
      localPivotY: (json['localPivotY'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NodeEntity {
  const NodeEntity({
    required this.id,
    required this.type,
    required this.label,
    required this.zIndex,
    required this.visible,
    required this.locked,
    required this.transform,
    required this.geometry,
    required this.style,
    this.text,
    this.parentId,
    this.containment,
    this.version = const NodeVersion(),
  });

  final NodeId id;
  final NodeEntityType type;
  final String label;
  final int zIndex;
  final bool visible;
  final bool locked;
  final NodeTransformData transform;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> style;
  final String? text;
  final NodeId? parentId;
  final NodeContainmentData? containment;
  final NodeVersion version;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'zIndex': zIndex,
      'visible': visible,
      'locked': locked,
      'transform': transform.toJson(),
      'geometry': geometry,
      'style': style,
      'text': text,
      'parentId': parentId,
      'containment': containment?.toJson(),
      'version': version.toJson(),
    };
  }

  factory NodeEntity.fromJson(Map<String, dynamic> json) {
    return NodeEntity(
      id: (json['id'] as String?) ?? '',
      type: nodeEntityTypeFromName((json['type'] as String?) ?? 'rect'),
      label: (json['label'] as String?) ?? 'Node',
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      visible: (json['visible'] as bool?) ?? true,
      locked: (json['locked'] as bool?) ?? false,
      transform: NodeTransformData.fromJson(
        (json['transform'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      geometry:
          (json['geometry'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      style:
          (json['style'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      text: json['text'] as String?,
      parentId: json['parentId'] as String?,
      containment: (json['containment'] as Map?)?.cast<String, dynamic>().let(
        NodeContainmentData.fromJson,
      ),
      version: NodeVersion.fromJson(
        (json['version'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  NodeEntity copyWith({
    NodeId? id,
    NodeEntityType? type,
    String? label,
    int? zIndex,
    bool? visible,
    bool? locked,
    NodeTransformData? transform,
    Map<String, dynamic>? geometry,
    Map<String, dynamic>? style,
    String? text,
    bool clearText = false,
    NodeId? parentId,
    bool clearParentId = false,
    NodeContainmentData? containment,
    bool clearContainment = false,
    NodeVersion? version,
  }) {
    return NodeEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      transform: transform ?? this.transform,
      geometry: geometry ?? this.geometry,
      style: style ?? this.style,
      text: clearText ? null : (text ?? this.text),
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      containment: clearContainment ? null : (containment ?? this.containment),
      version: version ?? this.version,
    );
  }
}

extension _MapLet<K, V> on Map<K, V> {
  T let<T>(T Function(Map<K, V>) mapper) => mapper(this);
}
