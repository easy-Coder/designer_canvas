import 'package:flutter/material.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section_header.dart';

/// Standard wrapper for every inspector property group: title row, body, divider.
///
/// Use this for all sections (Label, Position, Fill, type-specific, etc.) so new
/// node properties can be added as additional [InspectorSection]s in the list.
class InspectorSection extends StatelessWidget {
  const InspectorSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showDivider = true,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InspectorSectionHeader(title, trailing: trailing),
        child,
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}
