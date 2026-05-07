import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_palette.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_section.dart';

/// Text typography and background controls.
class InspectorTextSection extends StatelessWidget {
  const InspectorTextSection({
    super.key,
    required this.style,
    required this.isTool,
    required this.fontFamilyController,
    required this.palette,
    required this.onApplyToolStyle,
    required this.onPatchTextNodes,
  });

  final TextNodeStyle style;
  final bool isTool;
  final TextEditingController fontFamilyController;
  final List<ui.Color> palette;
  final ValueChanged<TextNodeStyle> onApplyToolStyle;
  final void Function(void Function(TextNode n) patch) onPatchTextNodes;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'Text',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: fontFamilyController,
            decoration: const InputDecoration(
              labelText: 'Font family',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (isTool) {
                onApplyToolStyle(
                  style.copyWith(
                    fontFamily: value.trim(),
                    clearFontFamily: value.trim().isEmpty,
                  ),
                );
              } else {
                onPatchTextNodes((n) {
                  n.style = n.textStyle.copyWith(
                    fontFamily: value.trim(),
                    clearFontFamily: value.trim().isEmpty,
                  );
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Font size: ${style.fontSize.toStringAsFixed(0)}'),
          Slider(
            value: style.fontSize.clamp(8, 120),
            min: 8,
            max: 120,
            onChanged: (v) {
              if (isTool) {
                onApplyToolStyle(style.copyWith(fontSize: v));
              } else {
                onPatchTextNodes((n) {
                  n.style = n.textStyle.copyWith(fontSize: v);
                });
              }
            },
          ),
          SegmentedButton<NodeTextLayoutMode>(
            segments: const [
              ButtonSegment(
                value: NodeTextLayoutMode.autoWidthAutoHeight,
                label: Text('Auto'),
              ),
              ButtonSegment(
                value: NodeTextLayoutMode.fixedSize,
                label: Text('Fixed'),
              ),
            ],
            selected: {style.layoutMode},
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              final mode = value.first;
              if (isTool) {
                onApplyToolStyle(style.copyWith(layoutMode: mode));
              } else {
                onPatchTextNodes((n) {
                  var next = n.textStyle.copyWith(layoutMode: mode);
                  if (mode == NodeTextLayoutMode.fixedSize) {
                    next = next.copyWith(
                      fixedWidth: n.rectWidth,
                      fixedHeight: n.rectHeight,
                    );
                  }
                  n.style = next;
                });
              }
            },
            showSelectedIcon: false,
          ),
          Row(
            children: [
              const Text('Background'),
              const Spacer(),
              Switch(
                value: style.backgroundColor != null,
                onChanged: (value) {
                  final next = style.copyWith(
                    backgroundColor: value
                        ? (style.backgroundColor ?? const ui.Color(0x20000000))
                        : null,
                    clearBackgroundColor: !value,
                  );
                  if (isTool) {
                    onApplyToolStyle(next);
                  } else {
                    onPatchTextNodes((n) {
                      n.style = next;
                    });
                  }
                },
              ),
            ],
          ),
          if (style.backgroundColor != null) ...[
            InspectorColorPalette(
              colors: palette,
              selected: style.backgroundColor!,
              onChanged: (color) {
                final next = style.copyWith(backgroundColor: color.withAlpha(72));
                if (isTool) {
                  onApplyToolStyle(next);
                } else {
                  onPatchTextNodes((n) {
                    n.style = next;
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
