import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Compact circular swatches for quick solid color choice.
class InspectorColorPalette extends StatelessWidget {
  const InspectorColorPalette({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  final List<ui.Color> colors;
  final ui.Color selected;
  final ValueChanged<ui.Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          InkWell(
            onTap: () => onChanged(color),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(color.toARGB32()),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).dividerColor,
                  width: color == selected ? 2 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
