typedef NodeId = String;

/// Discriminator carried by every [NodeEntity] subtype.
///
/// `frame` always corresponds to [FrameNodeEntity]; everything else is a
/// [LeafNodeEntity]. The enum is preserved exclusively so JSON payloads keep a
/// flat, human-readable type tag.
enum NodeEntityType {
  rect,
  frame,
  circle,
  line,
  text,
  arrow,
  polygon,
  star,
  image,
}

NodeEntityType nodeEntityTypeFromName(String raw) {
  return NodeEntityType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => NodeEntityType.rect,
  );
}

/// World-space top-left position for a node. All other geometry (width,
/// height, rotation, shape-specific anchors) lives in [NodeEntity.metadata].
class NodePos {
  const NodePos(this.x, this.y);

  final double x;
  final double y;

  NodePos copyWith({double? x, double? y}) {
    return NodePos(x ?? this.x, y ?? this.y);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory NodePos.fromJson(Map<String, dynamic> json) {
    return NodePos(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NodePos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Sealed root for every node record stored in [CanvasDocumentState].
///
/// Concrete types: [LeafNodeEntity] (any non-frame node) and
/// [FrameNodeEntity] (only kind that owns `children`). Exhaustive `switch`
/// statements over [NodeEntity] therefore enforce the "only frames have
/// children" invariant at compile time.
///
/// Reserved keys inside [metadata]:
///   - common: `width`, `height`, `rotation`, `zIndex`, `visible`, `locked`
///   - rect/frame/polygon/star/image: `fill`, `stroke`, `shadow`, `cornerRadius`, `sides`
///   - circle: `radius`
///   - line/arrow: `startX`, `startY`, `endX`, `endY`, `stroke`, `shadow`
///   - image: `sourceFileName`, `sourceFilePath`, `intrinsicWidth`, `intrinsicHeight`
///   - text: `text`, `color`, `fontFamily`, `fontSize`, `fontStyle`,
///           `fontWeight`, `textAlign`, `verticalAlign`, `layoutMode`,
///           `fixedWidth`, `fixedHeight`, `backgroundColor`,
///           `backgroundCornerRadius`
sealed class NodeEntity {
  const NodeEntity({
    required this.id,
    required this.name,
    required this.pos,
    required this.metadata,
  });

  final NodeId id;
  final String name;
  final NodePos pos;
  final Map<String, dynamic> metadata;

  NodeEntityType get type;

  /// Encodes the entity to a flat JSON map. Subtypes append `children` only
  /// where appropriate.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'pos': pos.toJson(),
      'metadata': Map<String, dynamic>.from(metadata),
    };
  }

  /// Dispatches to [FrameNodeEntity.fromJson] or [LeafNodeEntity.fromJson]
  /// based on the `type` discriminator.
  static NodeEntity fromJson(Map<String, dynamic> json) {
    final type = nodeEntityTypeFromName((json['type'] as String?) ?? 'rect');
    if (type == NodeEntityType.frame) {
      return FrameNodeEntity.fromJson(json);
    }
    return LeafNodeEntity.fromJson(json);
  }
}

/// Any non-frame node. Cannot have children.
class LeafNodeEntity extends NodeEntity {
  LeafNodeEntity({
    required super.id,
    required super.name,
    required super.pos,
    required Map<String, dynamic> metadata,
    required NodeEntityType type,
  })  : assert(
          type != NodeEntityType.frame,
          'Use FrameNodeEntity for frame nodes',
        ),
        _type = type,
        super(metadata: Map<String, dynamic>.from(metadata));

  final NodeEntityType _type;

  @override
  NodeEntityType get type => _type;

  LeafNodeEntity copyWith({
    String? name,
    NodePos? pos,
    Map<String, dynamic>? metadata,
  }) {
    return LeafNodeEntity(
      id: id,
      name: name ?? this.name,
      pos: pos ?? this.pos,
      metadata: metadata ?? this.metadata,
      type: type,
    );
  }

  factory LeafNodeEntity.fromJson(Map<String, dynamic> json) {
    return LeafNodeEntity(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Node',
      pos: NodePos.fromJson(
        (json['pos'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      type: nodeEntityTypeFromName((json['type'] as String?) ?? 'rect'),
    );
  }
}

/// A frame node; the only kind that owns child node ids.
class FrameNodeEntity extends NodeEntity {
  FrameNodeEntity({
    required super.id,
    required super.name,
    required super.pos,
    required Map<String, dynamic> metadata,
    List<NodeId> children = const <NodeId>[],
  })  : children = List<NodeId>.unmodifiable(children),
        super(metadata: Map<String, dynamic>.from(metadata));

  final List<NodeId> children;

  @override
  NodeEntityType get type => NodeEntityType.frame;

  FrameNodeEntity copyWith({
    String? name,
    NodePos? pos,
    Map<String, dynamic>? metadata,
    List<NodeId>? children,
  }) {
    return FrameNodeEntity(
      id: id,
      name: name ?? this.name,
      pos: pos ?? this.pos,
      metadata: metadata ?? this.metadata,
      children: children ?? this.children,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final base = super.toJson();
    base['children'] = List<NodeId>.from(children);
    return base;
  }

  factory FrameNodeEntity.fromJson(Map<String, dynamic> json) {
    return FrameNodeEntity(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Frame',
      pos: NodePos.fromJson(
        (json['pos'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      children: (json['children'] as List? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
