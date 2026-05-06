import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/color_picker_popover.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_palette.dart';

/// Drop shadow color and offsets inside the Effects section.
class InspectorShadowControls extends StatelessWidget {
  const InspectorShadowControls({
    super.key,
    required this.shadow,
    required this.onChanged,
    required this.palette,
    this.isMixed = false,
  });

  final ShadowStyleData? shadow;
  final ValueChanged<ShadowStyleData?> onChanged;
  final List<ui.Color> palette;
  final bool isMixed;

  void _pickColor(BuildContext context, ShadowStyleData current) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: ColorPickerPopover(
            initial: FillStyleData(color: current.color, kind: FillKind.solid),
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
        shadow ?? const ShadowStyleData(color: ui.Color(0x55000000));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Shadow', style: theme.textTheme.labelSmall),
            const Spacer(),
            Switch(
              value: shadow != null,
              onChanged: (v) => onChanged(v ? current : null),
            ),
          ],
        ),
        if (shadow != null) ...[
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
          Text('Offset X: ${current.offsetX.toStringAsFixed(1)}'),
          Slider(
            value: current.offsetX.clamp(-40, 40),
            min: -40,
            max: 40,
            onChanged: isMixed ? null : (v) => onChanged(current.copyWith(offsetX: v)),
          ),
          Text('Offset Y: ${current.offsetY.toStringAsFixed(1)}'),
          Slider(
            value: current.offsetY.clamp(-40, 40),
            min: -40,
            max: 40,
            onChanged: isMixed ? null : (v) => onChanged(current.copyWith(offsetY: v)),
          ),
          Text('Blur: ${current.blurRadius.toStringAsFixed(1)}'),
          Slider(
            value: current.blurRadius.clamp(0, 50),
            min: 0,
            max: 50,
            onChanged: isMixed ? null : (v) => onChanged(current.copyWith(blurRadius: v)),
          ),
        ],
      ],
    );
  }
}
