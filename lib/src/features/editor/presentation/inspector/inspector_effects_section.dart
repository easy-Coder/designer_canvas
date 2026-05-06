import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section_header.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_shadow_controls.dart';

/// Layer effects: shadow (functional) plus placeholder copy for future effects.
class InspectorEffectsSection extends StatelessWidget {
  const InspectorEffectsSection({
    super.key,
    required this.shadow,
    required this.onShadowChanged,
    required this.palette,
    this.isMixedShadow = false,
  });

  final ShadowStyleData? shadow;
  final ValueChanged<ShadowStyleData?> onShadowChanged;
  final List<ui.Color> palette;
  final bool isMixedShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InspectorSectionHeader(
          'Effects',
          trailing: IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {},
            tooltip: 'More effects (soon)',
          ),
        ),
        Text(
          'Additional layer effects will appear here.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        InspectorShadowControls(
          shadow: shadow,
          onChanged: onShadowChanged,
          palette: palette,
          isMixed: isMixedShadow,
        ),
      ],
    );
  }
}
