import 'package:flutter/material.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section.dart';

/// Polygon-specific inspector block (e.g. side count).
class InspectorPolygonSection extends StatelessWidget {
  const InspectorPolygonSection({
    super.key,
    required this.style,
    required this.isTool,
    required this.onApplyToolStyle,
    required this.onPatchPolygonNodes,
  });

  final PolygonNodeStyle style;
  final bool isTool;
  final ValueChanged<PolygonNodeStyle> onApplyToolStyle;
  final void Function(void Function(PolygonNode n) patch) onPatchPolygonNodes;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'Polygon',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sides: ${style.side}'),
          Slider(
            value: style.side.toDouble().clamp(3, 64),
            min: 3,
            max: 64,
            onChanged: (v) {
              if (isTool) {
                onApplyToolStyle(style.copyWith(side: v.toInt()));
              } else {
                onPatchPolygonNodes((n) {
                  n.style = n.polyStyle.copyWith(side: v.toInt());
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
