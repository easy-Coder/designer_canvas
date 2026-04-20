import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'circle_node.dart';
import 'line_node.dart';
import 'rect_node.dart';
import 'text_node.dart';
import 'triangle_node.dart';

class PropertyInspector extends StatelessWidget {
  const PropertyInspector({
    super.key,
    required this.controller,
  });

  final InfiniteCanvasController controller;

  static const List<ui.Color> _palette = <ui.Color>[
    ui.Color(0xFF1E88E5),
    ui.Color(0xFF43A047),
    ui.Color(0xFFF4511E),
    ui.Color(0xFF8E24AA),
    ui.Color(0xFF3949AB),
    ui.Color(0xFF00897B),
    ui.Color(0xFFC62828),
    ui.Color(0xFF37474F),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final node = controller.primaryNode;
        if (node == null) {
          return Center(
            child: Text(
              'Select a node to edit properties',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _nodeLabel(node),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_nodeColor(node) case final color?) ...[
              Text('Color', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _ColorPalette(
                colors: _palette,
                selected: color,
                onChanged: (value) {
                  _setNodeColor(node, value);
                  controller.requestRepaint();
                },
              ),
              const SizedBox(height: 16),
            ],
            if (node is RectNode) ...[
              Text('Corner radius', style: theme.textTheme.labelLarge),
              Slider(
                value: node.cornerRadiusWorld.clamp(0.0, 80.0),
                min: 0,
                max: 80,
                onChanged: (value) {
                  node.cornerRadiusWorld = value;
                  controller.requestRepaint();
                },
              ),
              const SizedBox(height: 8),
            ],
            if (node is TextNode) ...[
              Text('Text align', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TextAlign>(
                segments: const [
                  ButtonSegment(
                    value: TextAlign.left,
                    icon: Icon(Icons.format_align_left),
                    label: Text('Left'),
                  ),
                  ButtonSegment(
                    value: TextAlign.center,
                    icon: Icon(Icons.format_align_center),
                    label: Text('Center'),
                  ),
                  ButtonSegment(
                    value: TextAlign.right,
                    icon: Icon(Icons.format_align_right),
                    label: Text('Right'),
                  ),
                  ButtonSegment(
                    value: TextAlign.justify,
                    icon: Icon(Icons.format_align_justify),
                    label: Text('Justify'),
                  ),
                ],
                selected: {node.textAlign},
                onSelectionChanged: (selection) {
                  final value = selection.firstOrNull;
                  if (value == null) return;
                  node.textAlign = value;
                  controller.requestRepaint();
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              Text('Vertical align', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TextNodeVerticalAlign>(
                segments: const [
                  ButtonSegment(
                    value: TextNodeVerticalAlign.top,
                    label: Text('Top'),
                  ),
                  ButtonSegment(
                    value: TextNodeVerticalAlign.center,
                    label: Text('Center'),
                  ),
                  ButtonSegment(
                    value: TextNodeVerticalAlign.bottom,
                    label: Text('Bottom'),
                  ),
                ],
                selected: {node.verticalAlign},
                onSelectionChanged: (selection) {
                  final value = selection.firstOrNull;
                  if (value == null) return;
                  node.verticalAlign = value;
                  controller.requestRepaint();
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Background', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Switch(
                    value: node.backgroundColor != null,
                    onChanged: (enabled) {
                      node.backgroundColor ??=
                          const ui.Color(0x1F000000);
                      if (!enabled) {
                        node.backgroundColor = null;
                      }
                      controller.requestRepaint();
                    },
                  ),
                ],
              ),
              if (node.backgroundColor != null) ...[
                const SizedBox(height: 8),
                _ColorPalette(
                  colors: _palette,
                  selected: node.backgroundColor!,
                  onChanged: (value) {
                    node.backgroundColor = value.withAlpha(72);
                    controller.requestRepaint();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Background radius',
                  style: theme.textTheme.labelLarge,
                ),
                Slider(
                  value: node.backgroundCornerRadiusWorld.clamp(0.0, 80.0),
                  min: 0,
                  max: 80,
                  onChanged: (value) {
                    node.backgroundCornerRadiusWorld = value;
                    controller.requestRepaint();
                  },
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  static String _nodeLabel(CanvasNode node) {
    if (node is RectNode) return 'Rectangle';
    if (node is CircleNode) return 'Circle';
    if (node is TriangleNode) return 'Triangle';
    if (node is LineNode) return 'Line';
    if (node is TextNode) return 'Text';
    return node.runtimeType.toString();
  }

  static ui.Color? _nodeColor(CanvasNode node) {
    if (node is RectNode) return node.color;
    if (node is CircleNode) return node.color;
    if (node is TriangleNode) return node.color;
    if (node is LineNode) return node.color;
    if (node is TextNode) return node.color;
    return null;
  }

  static void _setNodeColor(CanvasNode node, ui.Color color) {
    if (node is RectNode) {
      node.color = color;
      return;
    }
    if (node is CircleNode) {
      node.color = color;
      return;
    }
    if (node is TriangleNode) {
      node.color = color;
      return;
    }
    if (node is LineNode) {
      node.color = color;
      return;
    }
    if (node is TextNode) {
      node.color = color;
    }
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
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
