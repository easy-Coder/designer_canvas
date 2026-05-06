import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/color_picker_popover.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_palette.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section_header.dart';

/// Stroke color, width, and dash pattern.
class InspectorStrokeControls extends StatelessWidget {
  const InspectorStrokeControls({
    super.key,
    required this.stroke,
    required this.onChanged,
    required this.palette,
    this.allowDisable = true,
    this.enabled = true,
    this.isMixed = false,
  });

  final StrokeStyleData? stroke;
  final ValueChanged<StrokeStyleData?> onChanged;
  final List<ui.Color> palette;
  final bool allowDisable;
  final bool enabled;
  final bool isMixed;

  void _pickColor(BuildContext context, StrokeStyleData current) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: ColorPickerPopover(
            initial: FillStyleData(
              color: current.color,
              kind: FillKind.solid,
            ),
            solidOnly: true,
            onApply: (f) => onChanged(current.copyWith(color: f.swatchColor)),
            onClose: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current =
        stroke ?? const StrokeStyleData(color: ui.Color(0xFF111111), width: 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InspectorSectionHeader(
          'Stroke',
          trailing: allowDisable && enabled
              ? Switch(
                  value: stroke != null,
                  onChanged: (v) => onChanged(v ? current : null),
                )
              : null,
        ),
        if (!enabled)
          Text('Not applicable', style: theme.textTheme.bodySmall)
        else if (stroke != null || !allowDisable) ...[
          Row(
            children: [
              InkWell(
                onTap: isMixed ? null : () => _pickColor(context, current),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isMixed ? theme.disabledColor : Color(current.color.toARGB32()),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: isMixed
                      ? const Center(child: Text('—', style: TextStyle(fontSize: 10)))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InspectorColorPalette(
                  colors: palette,
                  selected: current.color,
                  onChanged: isMixed
                      ? (_) {}
                      : (c) => onChanged(current.copyWith(color: c)),
                ),
              ),
            ],
          ),
          Text('Width: ${current.width.toStringAsFixed(1)}'),
          Slider(
            value: current.width.clamp(0.5, 40),
            min: 0.5,
            max: 40,
            onChanged: isMixed ? null : (v) => onChanged(current.copyWith(width: v)),
          ),
          SegmentedButton<StrokePatternStyle>(
            segments: const [
              ButtonSegment(value: StrokePatternStyle.solid, label: Text('Solid')),
              ButtonSegment(value: StrokePatternStyle.dashed, label: Text('Dashed')),
              ButtonSegment(value: StrokePatternStyle.dotted, label: Text('Dotted')),
            ],
            selected: {current.pattern},
            onSelectionChanged: (value) {
              if (isMixed || value.isEmpty) return;
              onChanged(current.copyWith(pattern: value.first));
            },
            showSelectedIcon: false,
          ),
          if (current.pattern != StrokePatternStyle.solid) ...[
            Text('Dash: ${current.dashLength.toStringAsFixed(1)}'),
            Slider(
              value: current.dashLength.clamp(1, 64),
              min: 1,
              max: 64,
              onChanged: isMixed
                  ? null
                  : (v) => onChanged(current.copyWith(dashLength: v)),
            ),
            Text('Gap: ${current.dashGap.toStringAsFixed(1)}'),
            Slider(
              value: current.dashGap.clamp(1, 64),
              min: 1,
              max: 64,
              onChanged: isMixed
                  ? null
                  : (v) => onChanged(current.copyWith(dashGap: v)),
            ),
          ],
        ],
      ],
    );
  }
}
