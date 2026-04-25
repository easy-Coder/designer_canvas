import 'package:uuid/uuid.dart';

import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';

/// Generates unique [NodeId] values for new document entities.
class NodeIdGenerator {
  NodeIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  NodeId nextId() => _uuid.v4();
}
