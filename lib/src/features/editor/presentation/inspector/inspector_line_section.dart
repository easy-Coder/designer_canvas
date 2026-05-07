import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section.dart';

/// Line cap and join controls.
class InspectorLineSection extends StatelessWidget {
  const InspectorLineSection({
    super.key,
    required this.style,
    required this.isTool,
    required this.onApplyToolStyle,
    required this.onPatchLineNodes,
  });

  final LineNodeStyle style;
  final bool isTool;
  final ValueChanged<LineNodeStyle> onApplyToolStyle;
  final void Function(void Function(LineNode n) patch) onPatchLineNodes;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'Line',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ui.StrokeCap>(
            segments: const [
              ButtonSegment(value: ui.StrokeCap.butt, label: Text('Butt')),
              ButtonSegment(value: ui.StrokeCap.round, label: Text('Round')),
              ButtonSegment(value: ui.StrokeCap.square, label: Text('Square')),
            ],
            selected: {style.stroke.cap},
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              final cap = value.first;
              if (isTool) {
                onApplyToolStyle(
                  style.copyWith(stroke: style.stroke.copyWith(cap: cap)),
                );
              } else {
                onPatchLineNodes((n) {
                  n.style = n.lineStyle.copyWith(
                    stroke: n.lineStyle.stroke.copyWith(cap: cap),
                  );
                });
              }
            },
            showSelectedIcon: false,
          ),
          SegmentedButton<ui.StrokeJoin>(
            segments: const [
              ButtonSegment(value: ui.StrokeJoin.round, label: Text('Round')),
              ButtonSegment(value: ui.StrokeJoin.miter, label: Text('Miter')),
              ButtonSegment(value: ui.StrokeJoin.bevel, label: Text('Bevel')),
            ],
            selected: {style.stroke.join},
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              final j = value.first;
              if (isTool) {
                onApplyToolStyle(
                  style.copyWith(stroke: style.stroke.copyWith(join: j)),
                );
              } else {
                onPatchLineNodes((n) {
                  n.style = n.lineStyle.copyWith(
                    stroke: n.lineStyle.stroke.copyWith(join: j),
                  );
                });
              }
            },
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}
