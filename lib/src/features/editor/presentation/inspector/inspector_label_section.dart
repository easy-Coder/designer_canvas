import 'package:flutter/material.dart';

/// Label [TextField] for the selected node (no section title; parent wraps [InspectorSection]).
class InspectorLabelSection extends StatelessWidget {
  const InspectorLabelSection({
    super.key,
    required this.controller,
    required this.onChanged,
    this.textStyle,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: textStyle,
      decoration: const InputDecoration(
        labelText: 'Label',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
