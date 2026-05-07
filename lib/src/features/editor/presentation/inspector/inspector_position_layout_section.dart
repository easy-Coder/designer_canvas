import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/nodes/circle_node.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section.dart';

/// X/Y, rotation (degrees), then W/H for [RoundedRectCanvasMixin] nodes.
///
/// Renders two [InspectorSection]s: **Position** and **Layout**.
class InspectorPositionLayoutSection extends StatelessWidget {
  const InspectorPositionLayoutSection({
    super.key,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    this.mixedX = false,
    this.mixedY = false,
    this.mixedW = false,
    this.mixedH = false,
    this.mixedR = false,
    required this.onChanged,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double rotationDegrees;
  final bool mixedX;
  final bool mixedY;
  final bool mixedW;
  final bool mixedH;
  final bool mixedR;
  final void Function({
    required double centerX,
    required double centerY,
    required double width,
    required double height,
    required double rotationDegrees,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InspectorSection(
          title: 'Position',
          showDivider: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pair(
                theme,
                'X',
                centerX,
                mixedX,
                (v) => onChanged(
                      centerX: v,
                      centerY: centerY,
                      width: width,
                      height: height,
                      rotationDegrees: rotationDegrees,
                    ),
              ),
              _pair(
                theme,
                'Y',
                centerY,
                mixedY,
                (v) => onChanged(
                      centerX: centerX,
                      centerY: v,
                      width: width,
                      height: height,
                      rotationDegrees: rotationDegrees,
                    ),
              ),
              _pair(
                theme,
                'Rotation °',
                rotationDegrees,
                mixedR,
                (v) => onChanged(
                      centerX: centerX,
                      centerY: centerY,
                      width: width,
                      height: height,
                      rotationDegrees: v,
                    ),
              ),
            ],
          ),
        ),
        InspectorSection(
          title: 'Layout',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pair(
                theme,
                'W',
                width,
                mixedW,
                (v) => onChanged(
                      centerX: centerX,
                      centerY: centerY,
                      width: v,
                      height: height,
                      rotationDegrees: rotationDegrees,
                    ),
              ),
              _pair(
                theme,
                'H',
                height,
                mixedH,
                (v) => onChanged(
                      centerX: centerX,
                      centerY: centerY,
                      width: width,
                      height: v,
                      rotationDegrees: rotationDegrees,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pair(
    ThemeData theme,
    String label,
    double value,
    bool mixed,
    ValueChanged<double> onVal,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: TextFormField(
              initialValue: mixed ? '' : _fmt(value),
              key: ValueKey('$label-$value-$mixed'),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: mixed ? 'Mixed' : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
              ],
              onFieldSubmitted: (t) {
                final v = double.tryParse(t);
                if (v != null) onVal(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}

/// Applies layout to a single canvas node (world space).
void applyLayoutToNode(
  CanvasNode node, {
  required double centerX,
  required double centerY,
  required double width,
  required double height,
  required double rotationDegrees,
}) {
  final rot = rotationDegrees * math.pi / 180;
  final c = Offset(centerX, centerY);
  final w = width.clamp(1e-3, 1e6);
  final h = height.clamp(1e-3, 1e6);
  if (node is CircleNode) {
    node.setCenterAndRadius(c, math.max(w, h) / 2);
  } else if (node is RoundedRectCanvasMixin) {
    node.initRoundedRectGeometry(
      center: c,
      width: w,
      height: h,
      rotationRadians: rot,
    );
  }
}
