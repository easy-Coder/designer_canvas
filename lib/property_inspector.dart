import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'node_styles.dart';
import 'text_node.dart';
import 'tool_style_defaults.dart';

enum InspectorScope { selectedNode, toolDefaults }

class PropertyInspector extends StatefulWidget {
  const PropertyInspector({
    super.key,
    required this.controller,
    required this.tool,
    required this.toolDefaults,
  });

  final InfiniteCanvasController controller;
  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;

  @override
  State<PropertyInspector> createState() => _PropertyInspectorState();
}

class _PropertyInspectorState extends State<PropertyInspector> {
  InspectorScope _scope = InspectorScope.selectedNode;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _fontFamilyController = TextEditingController();

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

  static int _alpha(ui.Color color) => (color.toARGB32() >> 24) & 0xFF;

  InfiniteCanvasController get _controller => widget.controller;

  ValueNotifier<ToolStyleDefaults> get _toolDefaults => widget.toolDefaults;

  CanvasTool get _activeTool => widget.tool.value;

  CanvasNode? get _selectedNode => _controller.primaryNode;

  NodeStyle? get _currentStyle {
    if (_scope == InspectorScope.selectedNode) {
      return _selectedNode?.style;
    }
    return _toolDefaults.value.styleFor(_activeTool);
  }

  void _applyStyle(NodeStyle style) {
    if (_scope == InspectorScope.selectedNode) {
      final node = _selectedNode;
      if (node == null) return;
      node.style = style;
      final quadId = _controller.primaryQuadId;
      if (quadId != null) {
        _controller.updateNode(quadId);
      }
      _controller.requestRepaint();
      return;
    }
    _toolDefaults.value = _toolDefaults.value.withStyle(_activeTool, style);
  }

  void _syncControllers() {
    final node = _selectedNode;
    _labelController.text = node?.label ?? '';
    final style = _currentStyle;
    if (style is TextNodeStyle) {
      _fontFamilyController.text = style.fontFamily ?? '';
    } else {
      _fontFamilyController.text = '';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _fontFamilyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, widget.tool, _toolDefaults]),
      builder: (context, _) {
        _syncControllers();
        final style = _currentStyle;
        final node = _selectedNode;
        final isSelectedScope = _scope == InspectorScope.selectedNode;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<InspectorScope>(
              segments: const [
                ButtonSegment(
                  value: InspectorScope.selectedNode,
                  label: Text('Selected Node'),
                ),
                ButtonSegment(
                  value: InspectorScope.toolDefaults,
                  label: Text('Tool Default'),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                setState(() => _scope = value.first);
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            if (isSelectedScope && node == null)
              Text(
                'Select a node to edit properties',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              )
            else ...[
              Text(
                isSelectedScope
                    ? (node?.label ?? 'Node')
                    : _toolLabel(_activeTool),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (isSelectedScope && node != null) ...[
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    node.label = value.trim().isEmpty ? 'Node' : value.trim();
                    _controller.requestRepaint();
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (style != null) ..._buildControls(context, style),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _buildControls(BuildContext context, NodeStyle style) {
    if (style is TextNodeStyle) return _buildTextControls(context, style);
    if (style is RectNodeStyle) return _buildRectLikeControls(context, style);
    if (style is FrameNodeStyle) return _buildFrameControls(context, style);
    if (style is CircleNodeStyle) return _buildCircleControls(context, style);
    if (style is TriangleNodeStyle) {
      return _buildTriangleControls(context, style);
    }
    if (style is LineNodeStyle) return _buildLineControls(context, style);
    return [];
  }

  List<Widget> _buildTextControls(BuildContext context, TextNodeStyle style) {
    return [
      Text('Text color', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      _ColorPalette(
        colors: _palette,
        selected: style.color,
        onChanged: (color) => _applyStyle(style.copyWith(color: color)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _fontFamilyController,
        decoration: const InputDecoration(
          labelText: 'Font family',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          _applyStyle(
            style.copyWith(
              fontFamily: value.trim(),
              clearFontFamily: value.trim().isEmpty,
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      Text('Font size: ${style.fontSize.toStringAsFixed(0)}'),
      Slider(
        value: style.fontSize.clamp(8, 120),
        min: 8,
        max: 120,
        onChanged: (value) => _applyStyle(style.copyWith(fontSize: value)),
      ),
      Text('Font weight: ${style.fontWeight}'),
      Slider(
        value: style.fontWeight.toDouble().clamp(100, 900),
        min: 100,
        max: 900,
        divisions: 8,
        onChanged: (value) {
          _applyStyle(style.copyWith(fontWeight: (value ~/ 100) * 100));
        },
      ),
      SegmentedButton<ui.FontStyle>(
        segments: const [
          ButtonSegment(value: ui.FontStyle.normal, label: Text('Normal')),
          ButtonSegment(value: ui.FontStyle.italic, label: Text('Italic')),
        ],
        selected: {style.fontStyle},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          _applyStyle(style.copyWith(fontStyle: value.first));
        },
      ),
      const SizedBox(height: 12),
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
          var nextStyle = style.copyWith(layoutMode: mode);
          if (mode == NodeTextLayoutMode.fixedSize &&
              _scope == InspectorScope.selectedNode) {
            final node = _selectedNode;
            if (node is TextNode) {
              nextStyle = nextStyle.copyWith(
                fixedWidth: node.rectWidth,
                fixedHeight: node.rectHeight,
              );
            }
          }
          _applyStyle(nextStyle);
        },
      ),
      const SizedBox(height: 12),
      SegmentedButton<NodeTextAlign>(
        segments: const [
          ButtonSegment(
            value: NodeTextAlign.left,
            icon: Icon(Icons.format_align_left),
            label: Text('Left'),
          ),
          ButtonSegment(
            value: NodeTextAlign.center,
            icon: Icon(Icons.format_align_center),
            label: Text('Center'),
          ),
          ButtonSegment(
            value: NodeTextAlign.right,
            icon: Icon(Icons.format_align_right),
            label: Text('Right'),
          ),
        ],
        selected: {style.textAlign},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          _applyStyle(style.copyWith(textAlign: value.first));
        },
      ),
      const SizedBox(height: 12),
      SegmentedButton<NodeTextVerticalAlign>(
        segments: const [
          ButtonSegment(value: NodeTextVerticalAlign.top, label: Text('Top')),
          ButtonSegment(
            value: NodeTextVerticalAlign.center,
            label: Text('Center'),
          ),
          ButtonSegment(
            value: NodeTextVerticalAlign.bottom,
            label: Text('Bottom'),
          ),
        ],
        selected: {style.verticalAlign},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          _applyStyle(style.copyWith(verticalAlign: value.first));
        },
      ),
      const SizedBox(height: 12),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Background'),
          const Spacer(),
          Switch(
            value: style.backgroundColor != null,
            onChanged: (value) {
              _applyStyle(
                style.copyWith(
                  backgroundColor: value
                      ? (style.backgroundColor ?? const ui.Color(0x20000000))
                      : null,
                  clearBackgroundColor: !value,
                ),
              );
            },
          ),
        ],
      ),
      if (style.backgroundColor != null) ...[
        _ColorPalette(
          colors: _palette,
          selected: style.backgroundColor!,
          onChanged: (color) {
            _applyStyle(style.copyWith(backgroundColor: color.withAlpha(72)));
          },
        ),
        Text(
          'Background radius: ${style.backgroundCornerRadius.toStringAsFixed(0)}',
        ),
        Slider(
          value: style.backgroundCornerRadius.clamp(0, 80),
          min: 0,
          max: 80,
          onChanged: (value) {
            _applyStyle(style.copyWith(backgroundCornerRadius: value));
          },
        ),
      ],
    ];
  }

  List<Widget> _buildRectLikeControls(
    BuildContext context,
    RectNodeStyle style,
  ) {
    return [
      ..._fillControls(
        style.fill,
        onChanged: (fill) => _applyStyle(style.copyWith(fill: fill)),
      ),
      Text('Corner radius: ${style.cornerRadius.toStringAsFixed(0)}'),
      Slider(
        value: style.cornerRadius.clamp(0, 80),
        min: 0,
        max: 80,
        onChanged: (value) => _applyStyle(style.copyWith(cornerRadius: value)),
      ),
      ..._strokeControls(
        style.stroke,
        onChanged: (stroke) => _applyStyle(
          style.copyWith(stroke: stroke, clearStroke: stroke == null),
        ),
      ),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
    ];
  }

  List<Widget> _buildCircleControls(
    BuildContext context,
    CircleNodeStyle style,
  ) {
    return [
      ..._fillControls(
        style.fill,
        onChanged: (fill) => _applyStyle(style.copyWith(fill: fill)),
      ),
      ..._strokeControls(
        style.stroke,
        onChanged: (stroke) => _applyStyle(
          style.copyWith(stroke: stroke, clearStroke: stroke == null),
        ),
      ),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
    ];
  }

  List<Widget> _buildFrameControls(BuildContext context, FrameNodeStyle style) {
    return [
      ..._fillControls(
        style.fill,
        onChanged: (fill) => _applyStyle(style.copyWith(fill: fill)),
      ),
      ..._strokeControls(
        style.stroke,
        onChanged: (stroke) => _applyStyle(
          style.copyWith(stroke: stroke, clearStroke: stroke == null),
        ),
      ),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
    ];
  }

  List<Widget> _buildTriangleControls(
    BuildContext context,
    TriangleNodeStyle style,
  ) {
    return [
      ..._fillControls(
        style.fill,
        onChanged: (fill) => _applyStyle(style.copyWith(fill: fill)),
      ),
      ..._strokeControls(
        style.stroke,
        onChanged: (stroke) => _applyStyle(
          style.copyWith(stroke: stroke, clearStroke: stroke == null),
        ),
      ),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
    ];
  }

  List<Widget> _buildLineControls(BuildContext context, LineNodeStyle style) {
    return [
      ..._strokeControls(
        style.stroke,
        onChanged: (stroke) {
          if (stroke == null) return;
          _applyStyle(style.copyWith(stroke: stroke));
        },
        allowDisable: false,
      ),
      SegmentedButton<ui.StrokeCap>(
        segments: const [
          ButtonSegment(value: ui.StrokeCap.butt, label: Text('Butt')),
          ButtonSegment(value: ui.StrokeCap.round, label: Text('Round')),
          ButtonSegment(value: ui.StrokeCap.square, label: Text('Square')),
        ],
        selected: {style.stroke.cap},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          _applyStyle(
            style.copyWith(stroke: style.stroke.copyWith(cap: value.first)),
          );
        },
      ),
      const SizedBox(height: 12),
      SegmentedButton<ui.StrokeJoin>(
        segments: const [
          ButtonSegment(value: ui.StrokeJoin.round, label: Text('Round')),
          ButtonSegment(value: ui.StrokeJoin.miter, label: Text('Miter')),
          ButtonSegment(value: ui.StrokeJoin.bevel, label: Text('Bevel')),
        ],
        selected: {style.stroke.join},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          _applyStyle(
            style.copyWith(stroke: style.stroke.copyWith(join: value.first)),
          );
        },
      ),
      _shadowControls(
        style.shadow,
        onChanged: (shadow) => _applyStyle(
          style.copyWith(shadow: shadow, clearShadow: shadow == null),
        ),
      ),
    ];
  }

  List<Widget> _fillControls(
    FillStyleData fill, {
    required ValueChanged<FillStyleData> onChanged,
  }) {
    return [
      const Text('Fill'),
      const SizedBox(height: 8),
      _ColorPalette(
        colors: _palette,
        selected: fill.color,
        onChanged: (color) => onChanged(fill.copyWith(color: color)),
      ),
      Text('Fill alpha: ${_alpha(fill.color)}'),
      Slider(
        value: _alpha(fill.color).toDouble(),
        min: 0,
        max: 255,
        onChanged: (value) {
          onChanged(fill.copyWith(color: fill.color.withAlpha(value.toInt())));
        },
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _strokeControls(
    StrokeStyleData? stroke, {
    required ValueChanged<StrokeStyleData?> onChanged,
    bool allowDisable = true,
  }) {
    final current =
        stroke ?? const StrokeStyleData(color: ui.Color(0xFF111111), width: 2);
    return [
      Row(
        children: [
          const Text('Stroke'),
          const Spacer(),
          if (allowDisable)
            Switch(
              value: stroke != null,
              onChanged: (enabled) => onChanged(enabled ? current : null),
            ),
        ],
      ),
      if (stroke != null || !allowDisable) ...[
        _ColorPalette(
          colors: _palette,
          selected: current.color,
          onChanged: (color) => onChanged(current.copyWith(color: color)),
        ),
        Text('Stroke width: ${current.width.toStringAsFixed(1)}'),
        Slider(
          value: current.width.clamp(0.5, 40),
          min: 0.5,
          max: 40,
          onChanged: (value) => onChanged(current.copyWith(width: value)),
        ),
        SegmentedButton<StrokePatternStyle>(
          segments: const [
            ButtonSegment(
              value: StrokePatternStyle.solid,
              label: Text('Solid'),
            ),
            ButtonSegment(
              value: StrokePatternStyle.dashed,
              label: Text('Dashed'),
            ),
            ButtonSegment(
              value: StrokePatternStyle.dotted,
              label: Text('Dotted'),
            ),
          ],
          selected: {current.pattern},
          onSelectionChanged: (value) {
            if (value.isEmpty) return;
            onChanged(current.copyWith(pattern: value.first));
          },
        ),
        if (current.pattern != StrokePatternStyle.solid) ...[
          Text('Dash length: ${current.dashLength.toStringAsFixed(1)}'),
          Slider(
            value: current.dashLength.clamp(1, 64),
            min: 1,
            max: 64,
            onChanged: (value) =>
                onChanged(current.copyWith(dashLength: value)),
          ),
          Text('Dash gap: ${current.dashGap.toStringAsFixed(1)}'),
          Slider(
            value: current.dashGap.clamp(1, 64),
            min: 1,
            max: 64,
            onChanged: (value) => onChanged(current.copyWith(dashGap: value)),
          ),
        ],
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _shadowControls(
    ShadowStyleData? shadow, {
    required ValueChanged<ShadowStyleData?> onChanged,
  }) {
    final current =
        shadow ?? const ShadowStyleData(color: ui.Color(0x55000000));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Shadow'),
            const Spacer(),
            Switch(
              value: shadow != null,
              onChanged: (enabled) => onChanged(enabled ? current : null),
            ),
          ],
        ),
        if (shadow != null) ...[
          _ColorPalette(
            colors: _palette,
            selected: current.color,
            onChanged: (value) => onChanged(current.copyWith(color: value)),
          ),
          Text('Offset X: ${current.offsetX.toStringAsFixed(1)}'),
          Slider(
            value: current.offsetX.clamp(-40, 40),
            min: -40,
            max: 40,
            onChanged: (value) => onChanged(current.copyWith(offsetX: value)),
          ),
          Text('Offset Y: ${current.offsetY.toStringAsFixed(1)}'),
          Slider(
            value: current.offsetY.clamp(-40, 40),
            min: -40,
            max: 40,
            onChanged: (value) => onChanged(current.copyWith(offsetY: value)),
          ),
          Text('Blur: ${current.blurRadius.toStringAsFixed(1)}'),
          Slider(
            value: current.blurRadius.clamp(0, 50),
            min: 0,
            max: 50,
            onChanged: (value) =>
                onChanged(current.copyWith(blurRadius: value)),
          ),
        ],
      ],
    );
  }

  static String _toolLabel(CanvasTool t) {
    return switch (t) {
      CanvasTool.select => 'Select tool defaults',
      CanvasTool.frame => 'Frame defaults',
      CanvasTool.rect => 'Rectangle defaults',
      CanvasTool.circle => 'Circle defaults',
      CanvasTool.triangle => 'Triangle defaults',
      CanvasTool.line => 'Line defaults',
      CanvasTool.text => 'Text defaults',
    };
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
