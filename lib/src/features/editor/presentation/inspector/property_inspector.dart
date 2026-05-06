import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';
import 'package:designer_canvas/src/features/editor/domain/tool_style_defaults.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_appearance_section.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_palette.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_effects_section.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_fill_controls.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_position_layout_section.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_selection_helpers.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_stroke_controls.dart';
import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_style_compare.dart';

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

  InfiniteCanvasController get _c => widget.controller;

  List<(int quadId, CanvasNode node)> _orderedSelection() {
    final ids = _c.selectedQuadIds.toList()..sort();
    final out = <(int, CanvasNode)>[];
    for (final id in ids) {
      final n = _c.lookupNode(id);
      if (n != null) out.add((id, n));
    }
    out.sort((a, b) {
      final z = a.$2.zIndex.compareTo(b.$2.zIndex);
      if (z != 0) return z;
      return a.$1.compareTo(b.$1);
    });
    return out;
  }

  void _applyToSelection(void Function(CanvasNode n) patch) {
    if (_scope != InspectorScope.selectedNode) return;
    for (final (id, n) in _orderedSelection()) {
      patch(n);
      _c.updateNode(id);
    }
    _c.requestRepaint();
  }

  void _applyToolDefault(NodeStyle style) {
    widget.toolDefaults.value = widget.toolDefaults.value.withStyle(
      widget.tool.value,
      style,
    );
  }

  NodeStyle? get _representativeStyle {
    if (_scope == InspectorScope.toolDefaults) {
      return widget.toolDefaults.value.styleFor(widget.tool.value);
    }
    return _c.primaryNode?.style;
  }

  CanvasNode? get _primary => _c.primaryNode;

  void _syncControllers() {
    final node = _primary;
    _labelController.text = node?.label ?? '';
    final st = _representativeStyle;
    if (st is TextNodeStyle) {
      _fontFamilyController.text = st.fontFamily ?? '';
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

  FillStyleData? _fillFromStyle(NodeStyle? s) {
    if (s is RectNodeStyle) return s.fill;
    if (s is FrameNodeStyle) return s.fill;
    if (s is CircleNodeStyle) return s.fill;
    if (s is PolygonNodeStyle) return s.fill;
    if (s is TextNodeStyle) {
      return FillStyleData(color: s.color, kind: FillKind.solid);
    }
    return null;
  }

  StrokeStyleData? _strokeFromStyle(NodeStyle? s) {
    if (s is RectNodeStyle) return s.stroke;
    if (s is FrameNodeStyle) return s.stroke;
    if (s is CircleNodeStyle) return s.stroke;
    if (s is PolygonNodeStyle) return s.stroke;
    if (s is LineNodeStyle) return s.stroke;
    return null;
  }

  ShadowStyleData? _shadowFromStyle(NodeStyle? s) {
    if (s is RectNodeStyle) return s.shadow;
    if (s is FrameNodeStyle) return s.shadow;
    if (s is CircleNodeStyle) return s.shadow;
    if (s is PolygonNodeStyle) return s.shadow;
    if (s is LineNodeStyle) return s.shadow;
    if (s is TextNodeStyle) return s.shadow;
    return null;
  }

  double? _cornerFromStyle(NodeStyle? s) {
    if (s is RectNodeStyle) return s.cornerRadius;
    if (s is TextNodeStyle) return s.backgroundCornerRadius;
    return null;
  }

  bool _mixedFill(List<CanvasNode> nodes) {
    final list = nodes.where(nodeSupportsFill).toList();
    if (list.length <= 1) return false;
    final f0 = readFill(list.first)!;
    return list.skip(1).any((n) => !fillJsonEquals(readFill(n)!, f0));
  }

  bool _mixedStroke(List<CanvasNode> nodes) {
    if (nodes.length <= 1) return false;
    StrokeStyleData? s0;
    var first = true;
    for (final n in nodes) {
      final StrokeStyleData? stroke =
          n is LineNode ? n.lineStyle.stroke : readStroke(n);
      if (first) {
        s0 = stroke;
        first = false;
        continue;
      }
      if (stroke == null && s0 == null) continue;
      if (stroke == null || s0 == null) return true;
      if (!strokeJsonEquals(stroke, s0)) return true;
    }
    return false;
  }

  bool _mixedShadow(List<CanvasNode> nodes) {
    if (nodes.length <= 1) return false;
    ShadowStyleData? z0;
    for (final n in nodes) {
      final z = readShadow(n);
      z0 ??= z;
      if (z0 == null && z == null) continue;
      if (z0 == null || z == null) return true;
      if (!shadowJsonEquals(z, z0)) return true;
    }
    return false;
  }

  bool _mixedLayout(List<CanvasNode> nodes) {
    final lay = nodes.whereType<RoundedRectCanvasMixin>().toList();
    if (lay.length <= 1) return false;
    final a = lay.first;
    for (final b in lay.skip(1)) {
      if ((a.rectCenter.dx - b.rectCenter.dx).abs() > 1e-3) return true;
      if ((a.rectCenter.dy - b.rectCenter.dy).abs() > 1e-3) return true;
      if ((a.rectWidth - b.rectWidth).abs() > 1e-3) return true;
      if ((a.rectHeight - b.rectHeight).abs() > 1e-3) return true;
      if ((a.rotationRadians - b.rotationRadians).abs() > 1e-5) return true;
    }
    return false;
  }

  bool _mixedCorner(List<CanvasNode> nodes) {
    final withR = nodes.where(nodeSupportsCornerRadius).toList();
    if (withR.length <= 1) return false;
    final r0 = readCornerRadius(withR.first)!;
    return withR.skip(1).any((n) => (readCornerRadius(n)! - r0).abs() > 1e-3);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: const Color(0xFF252525),
        onSurface: const Color(0xFFE8E8E8),
        primary: const Color(0xFF4A9EFF),
        onPrimary: Colors.white,
      ),
      dividerColor: const Color(0xFF3D3D3D),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_c, widget.tool, widget.toolDefaults]),
      builder: (context, _) {
        _syncControllers();
        final pairs = _orderedSelection();
        final nodes = pairs.map((e) => e.$2).toList();
        final isTool = _scope == InspectorScope.toolDefaults;
        final isSel = _scope == InspectorScope.selectedNode;
        final primary = _primary;
        final style = _representativeStyle;

        if (isSel && pairs.isEmpty) {
          return Theme(
            data: dark,
            child: Center(
              child: Text(
                'Select a node to edit properties',
                style: dark.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final title = isTool
            ? _toolLabel(widget.tool.value)
            : pairs.length <= 1
                ? (primary?.label ?? 'Node')
                : 'Selection (${pairs.length})';

        final rep = _representativeStyle;
        final mergeFill = isTool ? <CanvasNode>[] : nodes.where(nodeSupportsFill).toList();
        final fill0 = _fillFromStyle(rep);
        final fillMixed = isTool ? false : _mixedFill(nodes);
        final stroke0 = _strokeFromStyle(rep);
        final strokeMixed = isTool ? false : _mixedStroke(nodes);
        final shadow0 = _shadowFromStyle(rep);
        final shadowMixed = isTool ? false : _mixedShadow(nodes);
        final layoutMixed = isTool ? false : _mixedLayout(nodes);
        final cornerMixed = isTool ? false : _mixedCorner(nodes);

        RoundedRectCanvasMixin? lay;
        if (primary case final RoundedRectCanvasMixin r) {
          lay = r;
        }

        double? cx, cy, w, h, rotDeg;
        if (lay != null) {
          cx = lay.rectCenter.dx;
          cy = lay.rectCenter.dy;
          w = lay.rectWidth;
          h = lay.rectHeight;
          rotDeg = lay.rotationRadians * 180 / 3.141592653589793;
        }

        final showLayout = !isTool && primary != null && nodeSupportsLayout(primary);
        final corner = isTool ? _cornerFromStyle(rep) : (primary == null ? null : readCornerRadius(primary));
        final fillOpacity = fill0 == null
            ? null
            : (fill0.swatchColor.a).clamp(0.0, 1.0);

        return Theme(
          data: dark,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              SegmentedButton<InspectorScope>(
                segments: const [
                  ButtonSegment(
                    value: InspectorScope.selectedNode,
                    label: Text('Selection'),
                  ),
                  ButtonSegment(
                    value: InspectorScope.toolDefaults,
                    label: Text('Tool default'),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (v) {
                  if (v.isEmpty) return;
                  setState(() => _scope = v.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              Text(title, style: dark.textTheme.titleMedium),
              const Divider(height: 24),
              if (isSel && primary != null) ...[
                TextField(
                  controller: _labelController,
                  style: dark.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _applyToSelection((n) {
                      n.label = value.trim().isEmpty ? 'Node' : value.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (showLayout && cx != null) ...[
                InspectorPositionLayoutSection(
                  centerX: cx,
                  centerY: cy!,
                  width: w!,
                  height: h!,
                  rotationDegrees: rotDeg!,
                  mixedX: layoutMixed,
                  mixedY: layoutMixed,
                  mixedW: layoutMixed,
                  mixedH: layoutMixed,
                  mixedR: layoutMixed,
                  onChanged: ({
                    required double centerX,
                    required double centerY,
                    required double width,
                    required double height,
                    required double rotationDegrees,
                  }) {
                    _applyToSelection(
                      (n) => applyLayoutToNode(
                        n,
                        centerX: centerX,
                        centerY: centerY,
                        width: width,
                        height: height,
                        rotationDegrees: rotationDegrees,
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
              ],
              if (style != null && fill0 != null) ...[
                InspectorAppearanceSection(
                  showOpacity: true,
                  opacity01: fillOpacity,
                  opacityMixed: fillMixed,
                  onOpacity: (o) {
                    if (isTool) {
                      _patchToolStyleOpacity(o);
                    } else {
                      _applyToSelection((n) {
                        final f = readFill(n);
                        if (f == null) return;
                        final sw = f.swatchColor;
                        final next = sw.withAlpha((o * 255).round().clamp(0, 255));
                        applyFill(n, f.copyWith(color: next));
                      });
                    }
                  },
                  showCornerRadius: corner != null,
                  cornerRadius: corner,
                  cornerMixed: cornerMixed,
                  onCornerRadius: (r) {
                    if (isTool) {
                      _patchToolCornerRadius(r);
                    } else {
                      _applyToSelection((n) => applyCornerRadius(n, r));
                    }
                  },
                ),
                const Divider(height: 24),
              ],
              if (fill0 != null)
                InspectorFillControls(
                  fill: fill0,
                  isMixed: fillMixed,
                  enabled: isTool || mergeFill.isNotEmpty,
                  solidOnly: !isTool &&
                      mergeFill.isNotEmpty &&
                      mergeFill.every((n) => n is TextNode),
                  palette: _palette,
                  onChanged: (f) {
                    if (isTool) {
                      _patchToolFill(f);
                    } else {
                      _applyToSelection((n) {
                        if (nodeSupportsFill(n)) applyFill(n, f);
                      });
                    }
                  },
                ),
              if (fill0 != null) const Divider(height: 24),
              InspectorStrokeControls(
                stroke: stroke0,
                isMixed: strokeMixed,
                enabled: isTool ||
                    nodes.any((n) => readStroke(n) != null || n is LineNode),
                allowDisable: !isTool && primary is! LineNode,
                palette: _palette,
                onChanged: (s) {
                  if (isTool) {
                    _patchToolStroke(s);
                  } else {
                    _applyToSelection((n) {
                      if (readStroke(n) != null || n is LineNode) {
                        applyStroke(n, s);
                      }
                    });
                  }
                },
              ),
              const Divider(height: 24),
              InspectorEffectsSection(
                shadow: shadow0,
                isMixedShadow: shadowMixed,
                palette: _palette,
                onShadowChanged: (s) {
                  if (isTool) {
                    _patchToolShadow(s);
                  } else {
                    _applyToSelection((n) => applyShadow(n, s));
                  }
                },
              ),
              if (style != null) ...[
                const Divider(height: 24),
                ..._typeSpecific(context, style, isTool, primary),
              ],
            ],
          ),
        );
      },
    );
  }

  void _patchToolFill(FillStyleData f) {
    final t = widget.tool.value;
    final d = widget.toolDefaults.value;
    final s = d.styleFor(t);
    final next = _withFill(s, f);
    if (next != null) _applyToolDefault(next);
  }

  void _patchToolStroke(StrokeStyleData? stroke) {
    final t = widget.tool.value;
    final d = widget.toolDefaults.value;
    final s = d.styleFor(t);
    final next = _withStroke(s, stroke);
    if (next != null) _applyToolDefault(next);
  }

  void _patchToolShadow(ShadowStyleData? shadow) {
    final t = widget.tool.value;
    final d = widget.toolDefaults.value;
    final s = d.styleFor(t);
    final next = _withShadow(s, shadow);
    if (next != null) _applyToolDefault(next);
  }

  void _patchToolStyleOpacity(double o) {
    final t = widget.tool.value;
    final d = widget.toolDefaults.value;
    final s = d.styleFor(t);
    final next = _withFillOpacity(s, o);
    if (next != null) _applyToolDefault(next);
  }

  void _patchToolCornerRadius(double r) {
    final t = widget.tool.value;
    final d = widget.toolDefaults.value;
    final s = d.styleFor(t);
    if (s is RectNodeStyle) {
      _applyToolDefault(s.copyWith(cornerRadius: r));
    }
  }

  NodeStyle? _withFill(NodeStyle s, FillStyleData f) {
    if (s is RectNodeStyle) return s.copyWith(fill: f);
    if (s is FrameNodeStyle) return s.copyWith(fill: f);
    if (s is CircleNodeStyle) return s.copyWith(fill: f);
    if (s is PolygonNodeStyle) return s.copyWith(fill: f);
    if (s is TextNodeStyle && f.kind == FillKind.solid) {
      return s.copyWith(color: f.swatchColor);
    }
    return null;
  }

  NodeStyle? _withStroke(NodeStyle s, StrokeStyleData? stroke) {
    if (s is RectNodeStyle) {
      return s.copyWith(stroke: stroke, clearStroke: stroke == null);
    }
    if (s is FrameNodeStyle) {
      return s.copyWith(stroke: stroke, clearStroke: stroke == null);
    }
    if (s is CircleNodeStyle) {
      return s.copyWith(stroke: stroke, clearStroke: stroke == null);
    }
    if (s is PolygonNodeStyle) {
      return s.copyWith(stroke: stroke, clearStroke: stroke == null);
    }
    if (s is LineNodeStyle && stroke != null) {
      return s.copyWith(stroke: stroke);
    }
    return null;
  }

  NodeStyle? _withShadow(NodeStyle s, ShadowStyleData? shadow) {
    if (s is RectNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    if (s is FrameNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    if (s is CircleNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    if (s is PolygonNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    if (s is LineNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    if (s is TextNodeStyle) {
      return s.copyWith(shadow: shadow, clearShadow: shadow == null);
    }
    return null;
  }

  NodeStyle? _withFillOpacity(NodeStyle s, double o) {
    final a = (o * 255).round().clamp(0, 255);
    if (s is RectNodeStyle) {
      final f = s.fill;
      return s.copyWith(
        fill: f.copyWith(color: f.swatchColor.withAlpha(a)),
      );
    }
    if (s is FrameNodeStyle) {
      final f = s.fill;
      return s.copyWith(fill: f.copyWith(color: f.swatchColor.withAlpha(a)));
    }
    if (s is CircleNodeStyle) {
      final f = s.fill;
      return s.copyWith(fill: f.copyWith(color: f.swatchColor.withAlpha(a)));
    }
    if (s is PolygonNodeStyle) {
      final f = s.fill;
      return s.copyWith(fill: f.copyWith(color: f.swatchColor.withAlpha(a)));
    }
    if (s is TextNodeStyle) {
      return s.copyWith(color: s.color.withAlpha(a));
    }
    return null;
  }

  List<Widget> _typeSpecific(
    BuildContext context,
    NodeStyle style,
    bool isTool,
    CanvasNode? primary,
  ) {
    if (style is TextNodeStyle) {
      return _textControls(context, style, isTool, primary);
    }
    if (style is RectNodeStyle) {
      return [];
    }
    if (style is PolygonNodeStyle) {
      return _polygonControls(style, isTool);
    }
    if (style is LineNodeStyle) {
      return _lineControls(context, style, isTool);
    }
    return [];
  }

  List<Widget> _polygonControls(PolygonNodeStyle style, bool isTool) {
    return [
      Text('Sides: ${style.side}'),
      Slider(
        value: style.side.toDouble().clamp(3, 64),
        min: 3,
        max: 64,
        onChanged: (v) {
          if (isTool) {
            _applyToolDefault(style.copyWith(side: v.toInt()));
          } else {
            _applyToSelection((n) {
              if (n is PolygonNode) {
                n.style = n.polyStyle.copyWith(side: v.toInt());
              }
            });
          }
        },
      ),
    ];
  }

  List<Widget> _lineControls(
    BuildContext context,
    LineNodeStyle style,
    bool isTool,
  ) {
    return [
      SegmentedButton<ui.StrokeCap>(
        segments: const [
          ButtonSegment(value: ui.StrokeCap.butt, label: Text('Butt')),
          ButtonSegment(value: ui.StrokeCap.round, label: Text('Round')),
          ButtonSegment(value: ui.StrokeCap.square, label: Text('Square')),
        ],
        selected: {style.stroke.cap},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          final cap = value.first;
          if (isTool) {
            _applyToolDefault(style.copyWith(stroke: style.stroke.copyWith(cap: cap)));
          } else {
            _applyToSelection((n) {
              if (n is LineNode) {
                n.style = n.lineStyle.copyWith(
                  stroke: n.lineStyle.stroke.copyWith(cap: cap),
                );
              }
            });
          }
        },
        showSelectedIcon: false,
      ),
      SegmentedButton<ui.StrokeJoin>(
        segments: const [
          ButtonSegment(value: ui.StrokeJoin.round, label: Text('Round')),
          ButtonSegment(value: ui.StrokeJoin.miter, label: Text('Miter')),
          ButtonSegment(value: ui.StrokeJoin.bevel, label: Text('Bevel')),
        ],
        selected: {style.stroke.join},
        onSelectionChanged: (value) {
          if (value.isEmpty) return;
          final j = value.first;
          if (isTool) {
            _applyToolDefault(style.copyWith(stroke: style.stroke.copyWith(join: j)));
          } else {
            _applyToSelection((n) {
              if (n is LineNode) {
                n.style = n.lineStyle.copyWith(
                  stroke: n.lineStyle.stroke.copyWith(join: j),
                );
              }
            });
          }
        },
        showSelectedIcon: false,
      ),
    ];
  }

  List<Widget> _textControls(
    BuildContext context,
    TextNodeStyle style,
    bool isTool,
    CanvasNode? primary,
  ) {
    return [
      TextField(
        controller: _fontFamilyController,
        decoration: const InputDecoration(
          labelText: 'Font family',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (isTool) {
            _applyToolDefault(
              style.copyWith(
                fontFamily: value.trim(),
                clearFontFamily: value.trim().isEmpty,
              ),
            );
          } else {
            _applyToSelection((n) {
              if (n is TextNode) {
                n.style = n.textStyle.copyWith(
                  fontFamily: value.trim(),
                  clearFontFamily: value.trim().isEmpty,
                );
              }
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
            _applyToolDefault(style.copyWith(fontSize: v));
          } else {
            _applyToSelection((n) {
              if (n is TextNode) n.style = n.textStyle.copyWith(fontSize: v);
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
            _applyToolDefault(style.copyWith(layoutMode: mode));
          } else {
            _applyToSelection((n) {
              if (n is! TextNode) return;
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
                _applyToolDefault(next);
              } else {
                _applyToSelection((n) {
                  if (n is TextNode) n.style = next;
                });
              }
            },
          ),
        ],
      ),
      if (style.backgroundColor != null) ...[
        InspectorColorPalette(
          colors: _palette,
          selected: style.backgroundColor!,
          onChanged: (color) {
            final next = style.copyWith(backgroundColor: color.withAlpha(72));
            if (isTool) {
              _applyToolDefault(next);
            } else {
              _applyToSelection((n) {
                if (n is TextNode) n.style = next;
              });
            }
          },
        ),
      ],
    ];
  }

  static String _toolLabel(CanvasTool t) {
    return switch (t) {
      CanvasTool.select => 'Select tool defaults',
      CanvasTool.frame => 'Frame defaults',
      CanvasTool.rect => 'Rectangle defaults',
      CanvasTool.circle => 'Circle defaults',
      CanvasTool.line => 'Line defaults',
      CanvasTool.pen => 'Pen defaults',
      CanvasTool.arrow => 'Arrow defaults',
      CanvasTool.polygon => 'Polygon defaults',
      CanvasTool.star => 'Star defaults',
      CanvasTool.image => 'Image defaults',
      CanvasTool.text => 'Text defaults',
    };
  }
}
