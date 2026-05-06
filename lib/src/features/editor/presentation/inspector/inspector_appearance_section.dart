import 'package:flutter/material.dart';

/// Opacity and shape-specific appearance (e.g. corner radius). Title lives on [InspectorSection].
class InspectorAppearanceSection extends StatelessWidget {
  const InspectorAppearanceSection({
    super.key,
    this.cornerRadius,
    this.onCornerRadius,
    this.cornerMixed = false,
    this.showCornerRadius = false,
    this.opacity01,
    this.onOpacity,
    this.opacityMixed = false,
    this.showOpacity = false,
  });

  final double? cornerRadius;
  final ValueChanged<double>? onCornerRadius;
  final bool cornerMixed;
  final bool showCornerRadius;
  final double? opacity01;
  final ValueChanged<double>? onOpacity;
  final bool opacityMixed;
  final bool showOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showOpacity && opacity01 != null && onOpacity != null) ...[
          Text('Opacity', style: theme.textTheme.labelSmall),
          Slider(
            value: opacityMixed ? 1.0 : opacity01!.clamp(0.0, 1.0),
            onChanged: opacityMixed
                ? null
                : (v) => onOpacity!(v),
          ),
        ],
        if (showCornerRadius && cornerRadius != null && onCornerRadius != null) ...[
          Text(
            cornerMixed
                ? 'Corner radius (mixed)'
                : 'Corner radius: ${cornerRadius!.toStringAsFixed(0)}',
            style: theme.textTheme.labelSmall,
          ),
          Slider(
            value: cornerMixed ? 0 : cornerRadius!.clamp(0, 80),
            max: 80,
            onChanged: cornerMixed ? null : onCornerRadius,
          ),
        ],
      ],
    );
  }
}
