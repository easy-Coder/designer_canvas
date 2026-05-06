import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/color_picker_popover.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_palette.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_utils.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section_header.dart';

/// Fill editor: quick palette, alpha slider, and full popover for gradients/images.
class InspectorFillControls extends StatelessWidget {
  const InspectorFillControls({
    super.key,
    required this.fill,
    required this.onChanged,
    required this.palette,
    this.enabled = true,
    this.solidOnly = false,
    this.isMixed = false,
  });

  final FillStyleData fill;
  final ValueChanged<FillStyleData> onChanged;
  final List<ui.Color> palette;
  final bool enabled;
  final bool solidOnly;
  final bool isMixed;

  static int _alpha(ui.Color color) => (color.a * 255.0).round().clamp(0, 255);

  void _showPicker(BuildContext context) {
    if (!enabled) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.only(right: 24, left: 200),
          child: ColorPickerPopover(
            initial: fill,
            solidOnly: solidOnly,
            onApply: onChanged,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatch = fill.swatchColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InspectorSectionHeader(
          'Fill',
          trailing: IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: enabled ? () => _showPicker(context) : null,
            tooltip: 'Edit fill',
          ),
        ),
        if (!enabled)
          Text(
            'Not applicable',
            style: theme.textTheme.bodySmall,
          )
        else ...[
          Row(
            children: [
              InkWell(
                onTap: () => _showPicker(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMixed ? theme.disabledColor : Color(swatch.toARGB32()),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: isMixed
                      ? const Center(child: Text('—', style: TextStyle(fontSize: 12)))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMixed ? 'Mixed' : fillHexRgb(swatch),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text('${((_alpha(swatch) / 255) * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          InspectorColorPalette(
            colors: palette,
            selected: swatch,
            onChanged: isMixed
                ? (_) {}
                : (c) => onChanged(
                      solidOnly ? fill.copyWithSolidColor(c) : fill.copyWithSolidColor(c),
                    ),
          ),
          Text('Opacity', style: theme.textTheme.labelSmall),
          Slider(
            value: _alpha(swatch).toDouble(),
            min: 0,
            max: 255,
            onChanged: enabled && !isMixed
                ? (v) => onChanged(
                      fill.copyWith(
                        color: swatch.withAlpha(v.round().clamp(0, 255)),
                      ),
                    )
                : null,
          ),
        ],
      ],
    );
  }
}
