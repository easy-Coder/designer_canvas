import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/presentation/inspector/inspector_color_utils.dart';

enum _ColorPickerTab { custom, libraries }

/// Modal-style panel for editing a [FillStyleData] (solid, gradients, image).
class ColorPickerPopover extends StatefulWidget {
  const ColorPickerPopover({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onClose,
    this.solidOnly = false,
  });

  final FillStyleData initial;
  final ValueChanged<FillStyleData> onApply;
  final VoidCallback onClose;
  final bool solidOnly;

  @override
  State<ColorPickerPopover> createState() => _ColorPickerPopoverState();
}

class _ColorPickerPopoverState extends State<ColorPickerPopover> {
  late FillStyleData _fill;
  _ColorPickerTab _tab = _ColorPickerTab.custom;
  late final TextEditingController _hexCtrl;
  int _opacity255 = 255;
  HSVColor _hsv = const HSVColor.fromAHSV(1, 0, 0, 1);

  @override
  void initState() {
    super.initState();
    _fill = _cloneFill(widget.initial);
    _hexCtrl = TextEditingController();
    _syncFromFill();
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  FillStyleData _cloneFill(FillStyleData f) {
    return FillStyleData.fromJson(Map<String, dynamic>.from(f.toJson()));
  }

  void _syncFromFill() {
    final c = _fill.swatchColor;
    _opacity255 = alpha255(c);
    _hexCtrl.text = fillHexRgb(ui.Color.fromARGB(
      255,
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    ));
    _hsv = HSVColor.fromColor(_toMaterialRgbOpaque(c));
  }

  Color _toMaterialRgbOpaque(ui.Color c) {
    return Color.fromARGB(
      255,
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    );
  }

  ui.Color _solidDraftColor() {
    final rgb = tryParseHexRgb(_hexCtrl.text) ?? _hsv.toColor();
    return ui.Color.fromARGB(
      _opacity255,
      (rgb.r * 255).round(),
      (rgb.g * 255).round(),
      (rgb.b * 255).round(),
    );
  }

  void _applySolidFromHsv() {
    final co = _hsv.toColor();
    final merged = ui.Color.fromARGB(
      _opacity255,
      (co.r * 255).round(),
      (co.g * 255).round(),
      (co.b * 255).round(),
    );
    setState(() {
      _fill = FillStyleData(
        color: merged,
        kind: FillKind.solid,
        stops: const <GradientColorStop>[],
        linearStartX: _fill.linearStartX,
        linearStartY: _fill.linearStartY,
        linearEndX: _fill.linearEndX,
        linearEndY: _fill.linearEndY,
        radialCenterX: _fill.radialCenterX,
        radialCenterY: _fill.radialCenterY,
        radialRadius: _fill.radialRadius,
        imagePath: _fill.imagePath,
        imageFit: _fill.imageFit,
      );
      _hexCtrl.text = fillHexRgb(merged);
    });
  }

  void _setKind(FillKind k) {
    setState(() {
      final base = _fill.swatchColor;
      switch (k) {
        case FillKind.solid:
          _fill = FillStyleData(
            color: base,
            kind: FillKind.solid,
            stops: const <GradientColorStop>[],
            linearStartX: _fill.linearStartX,
            linearStartY: _fill.linearStartY,
            linearEndX: _fill.linearEndX,
            linearEndY: _fill.linearEndY,
            radialCenterX: _fill.radialCenterX,
            radialCenterY: _fill.radialCenterY,
            radialRadius: _fill.radialRadius,
            imagePath: null,
            imageFit: _fill.imageFit,
          );
        case FillKind.linearGradient:
          _fill = FillStyleData(
            color: base,
            kind: FillKind.linearGradient,
            stops: <GradientColorStop>[
              GradientColorStop(offset: 0, color: base),
              GradientColorStop(
                offset: 1,
                color: base.withAlpha(0),
              ),
            ],
            linearStartX: 0,
            linearStartY: 0,
            linearEndX: 1,
            linearEndY: 0,
            radialCenterX: _fill.radialCenterX,
            radialCenterY: _fill.radialCenterY,
            radialRadius: _fill.radialRadius,
            imagePath: null,
            imageFit: _fill.imageFit,
          );
        case FillKind.radialGradient:
          _fill = FillStyleData(
            color: base,
            kind: FillKind.radialGradient,
            stops: <GradientColorStop>[
              GradientColorStop(offset: 0, color: base),
              GradientColorStop(
                offset: 1,
                color: base.withAlpha(0),
              ),
            ],
            linearStartX: _fill.linearStartX,
            linearStartY: _fill.linearStartY,
            linearEndX: _fill.linearEndX,
            linearEndY: _fill.linearEndY,
            radialCenterX: 0.5,
            radialCenterY: 0.5,
            radialRadius: 0.5,
            imagePath: null,
            imageFit: _fill.imageFit,
          );
        case FillKind.image:
          _fill = FillStyleData(
            color: base,
            kind: FillKind.image,
            stops: const <GradientColorStop>[],
            linearStartX: _fill.linearStartX,
            linearStartY: _fill.linearStartY,
            linearEndX: _fill.linearEndX,
            linearEndY: _fill.linearEndY,
            radialCenterX: _fill.radialCenterX,
            radialCenterY: _fill.radialCenterY,
            radialRadius: _fill.radialRadius,
            imagePath: _fill.imagePath,
            imageFit: _fill.imageFit,
          );
      }
      _syncFromFill();
    });
  }

  Future<void> _pickImageFile() async {
    const group = XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    final f = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (f == null) return;
    setState(() {
      _fill = FillStyleData(
        color: _fill.color,
        kind: FillKind.image,
        stops: const <GradientColorStop>[],
        linearStartX: _fill.linearStartX,
        linearStartY: _fill.linearStartY,
        linearEndX: _fill.linearEndX,
        linearEndY: _fill.linearEndY,
        radialCenterX: _fill.radialCenterX,
        radialCenterY: _fill.radialCenterY,
        radialRadius: _fill.radialRadius,
        imagePath: f.path,
        imageFit: _fill.imageFit,
      );
    });
  }

  Future<ui.Color?> _pickStopColor(ui.Color current) {
    return showDialog<ui.Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Stop color'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Colors.primaries)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, ui.Color(c.toARGB32())),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () => Navigator.pop(ctx, current),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _toMaterial(current),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Color _toMaterial(ui.Color c) {
    return Color.fromARGB(
      (c.a * 255).round(),
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF2C2C2C),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_ColorPickerTab>(
                        segments: const [
                          ButtonSegment(
                            value: _ColorPickerTab.custom,
                            label: Text('Custom'),
                          ),
                          ButtonSegment(
                            value: _ColorPickerTab.libraries,
                            label: Text('Libraries'),
                          ),
                        ],
                        selected: <_ColorPickerTab>{_tab},
                        onSelectionChanged: (s) {
                          if (s.isEmpty) return;
                          setState(() => _tab = s.first);
                        },
                        showSelectedIcon: false,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tab == _ColorPickerTab.libraries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Libraries coming soon',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else ...[
                  if (!widget.solidOnly) _kindToolbar(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _customBody(theme),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(onPressed: widget.onClose, child: const Text('Cancel')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (_fill.kind == FillKind.solid) {
                          _fill = FillStyleData(
                            color: _solidDraftColor(),
                            kind: FillKind.solid,
                            stops: const <GradientColorStop>[],
                            linearStartX: _fill.linearStartX,
                            linearStartY: _fill.linearStartY,
                            linearEndX: _fill.linearEndX,
                            linearEndY: _fill.linearEndY,
                            radialCenterX: _fill.radialCenterX,
                            radialCenterY: _fill.radialCenterY,
                            radialRadius: _fill.radialRadius,
                            imagePath: _fill.imagePath,
                            imageFit: _fill.imageFit,
                          );
                        }
                        widget.onApply(_fill);
                        widget.onClose();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kindToolbar() {
    return Row(
      children: [
        _kindIcon(Icons.square, FillKind.solid),
        _kindIcon(Icons.gradient, FillKind.linearGradient),
        _kindIcon(Icons.blur_circular, FillKind.radialGradient),
        _kindIcon(Icons.image, FillKind.image),
      ],
    );
  }

  Widget _kindIcon(IconData icon, FillKind k) {
    final sel = _fill.kind == k;
    return IconButton.filledTonal(
      isSelected: sel,
      onPressed: () => _setKind(k),
      icon: Icon(icon),
    );
  }

  Widget _customBody(ThemeData theme) {
    switch (_fill.kind) {
      case FillKind.solid:
        return _solidEditor(theme);
      case FillKind.linearGradient:
      case FillKind.radialGradient:
        return _gradientEditor(theme);
      case FillKind.image:
        return _imageEditor(theme);
    }
  }

  Widget _solidEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth.clamp(120.0, 280.0);
            final h = w * 0.55;
            return _SaturationValueField(
              width: w,
              height: h,
              hue: _hsv.hue,
              saturation: _hsv.saturation,
              value: _hsv.value,
              onChanged: (s, v) {
                setState(() {
                  _hsv = HSVColor.fromAHSV(1, _hsv.hue, s, v);
                  _applySolidFromHsv();
                });
              },
            );
          },
        ),
        Text('Hue', style: theme.textTheme.labelSmall),
        Slider(
          value: _hsv.hue.clamp(0.0, 359.99),
          max: 360,
          onChanged: (h) {
            setState(() {
              _hsv = HSVColor.fromAHSV(1, h, _hsv.saturation, _hsv.value);
              _applySolidFromHsv();
            });
          },
        ),
        Text('Opacity', style: theme.textTheme.labelSmall),
        Slider(
          value: _opacity255.toDouble(),
          max: 255,
          onChanged: (o) {
            setState(() {
              _opacity255 = o.round();
              _applySolidFromHsv();
            });
          },
        ),
        Row(
          children: [
            const Text('Hex'),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: _hexCtrl,
                onSubmitted: (t) {
                  final p = tryParseHexRgb(t);
                  if (p != null) {
                    setState(() {
                      _hsv = HSVColor.fromColor(_toMaterialRgbOpaque(p));
                      _applySolidFromHsv();
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gradientEditor(ThemeData theme) {
    final stops = _fill.effectiveStops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stops.length; i++)
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('${(stops[i].offset * 100).round()}%'),
              ),
              Expanded(
                child: Slider(
                  value: stops[i].offset.clamp(0.0, 1.0),
                  onChanged: (v) {
                    setState(() {
                      final next = List<GradientColorStop>.from(stops);
                      next[i] = next[i].copyWith(offset: v);
                      _fill = FillStyleData(
                        color: _fill.color,
                        kind: _fill.kind,
                        stops: next,
                        linearStartX: _fill.linearStartX,
                        linearStartY: _fill.linearStartY,
                        linearEndX: _fill.linearEndX,
                        linearEndY: _fill.linearEndY,
                        radialCenterX: _fill.radialCenterX,
                        radialCenterY: _fill.radialCenterY,
                        radialRadius: _fill.radialRadius,
                        imagePath: _fill.imagePath,
                        imageFit: _fill.imageFit,
                      );
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.color_lens, size: 20),
                onPressed: () async {
                  final picked = await _pickStopColor(stops[i].color);
                  if (picked != null && mounted) {
                    setState(() {
                      final next = List<GradientColorStop>.from(stops);
                      next[i] = next[i].copyWith(color: picked);
                      _fill = FillStyleData(
                        color: _fill.color,
                        kind: _fill.kind,
                        stops: next,
                        linearStartX: _fill.linearStartX,
                        linearStartY: _fill.linearStartY,
                        linearEndX: _fill.linearEndX,
                        linearEndY: _fill.linearEndY,
                        radialCenterX: _fill.radialCenterX,
                        radialCenterY: _fill.radialCenterY,
                        radialRadius: _fill.radialRadius,
                        imagePath: _fill.imagePath,
                        imageFit: _fill.imageFit,
                      );
                    });
                  }
                },
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                final next = List<GradientColorStop>.from(stops)
                  ..add(
                    GradientColorStop(
                      offset: 0.5,
                      color: _fill.swatchColor,
                    ),
                  );
                _fill = FillStyleData(
                  color: _fill.color,
                  kind: _fill.kind,
                  stops: next,
                  linearStartX: _fill.linearStartX,
                  linearStartY: _fill.linearStartY,
                  linearEndX: _fill.linearEndX,
                  linearEndY: _fill.linearEndY,
                  radialCenterX: _fill.radialCenterX,
                  radialCenterY: _fill.radialCenterY,
                  radialRadius: _fill.radialRadius,
                  imagePath: _fill.imagePath,
                  imageFit: _fill.imageFit,
                );
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Stop'),
          ),
        ),
        if (_fill.kind == FillKind.linearGradient) ...[
          Text('Axis', style: theme.textTheme.labelSmall),
          Text('End X', style: theme.textTheme.labelSmall),
          Slider(
            value: _fill.linearEndX.clamp(0.0, 1.0),
            onChanged: (v) => setState(() {
              _fill = FillStyleData(
                color: _fill.color,
                kind: _fill.kind,
                stops: _fill.stops,
                linearStartX: _fill.linearStartX,
                linearStartY: _fill.linearStartY,
                linearEndX: v,
                linearEndY: _fill.linearEndY,
                radialCenterX: _fill.radialCenterX,
                radialCenterY: _fill.radialCenterY,
                radialRadius: _fill.radialRadius,
                imagePath: _fill.imagePath,
                imageFit: _fill.imageFit,
              );
            }),
          ),
          Text('End Y', style: theme.textTheme.labelSmall),
          Slider(
            value: _fill.linearEndY.clamp(0.0, 1.0),
            onChanged: (v) => setState(() {
              _fill = FillStyleData(
                color: _fill.color,
                kind: _fill.kind,
                stops: _fill.stops,
                linearStartX: _fill.linearStartX,
                linearStartY: _fill.linearStartY,
                linearEndX: _fill.linearEndX,
                linearEndY: v,
                radialCenterX: _fill.radialCenterX,
                radialCenterY: _fill.radialCenterY,
                radialRadius: _fill.radialRadius,
                imagePath: _fill.imagePath,
                imageFit: _fill.imageFit,
              );
            }),
          ),
        ] else ...[
          Text('Radius', style: theme.textTheme.labelSmall),
          Slider(
            value: _fill.radialRadius.clamp(0.05, 1.0),
            onChanged: (v) => setState(() {
              _fill = FillStyleData(
                color: _fill.color,
                kind: _fill.kind,
                stops: _fill.stops,
                linearStartX: _fill.linearStartX,
                linearStartY: _fill.linearStartY,
                linearEndX: _fill.linearEndX,
                linearEndY: _fill.linearEndY,
                radialCenterX: _fill.radialCenterX,
                radialCenterY: _fill.radialCenterY,
                radialRadius: v,
                imagePath: _fill.imagePath,
                imageFit: _fill.imageFit,
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _imageEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _pickImageFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('Choose image…'),
        ),
        if (_fill.imagePath != null)
          Text(
            _fill.imagePath!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        Text('Fit', style: theme.textTheme.labelSmall),
        DropdownButton<FillImageFit>(
          value: _fill.imageFit,
          isExpanded: true,
          items: FillImageFit.values
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.name),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _fill = FillStyleData(
                color: _fill.color,
                kind: FillKind.image,
                stops: _fill.stops,
                linearStartX: _fill.linearStartX,
                linearStartY: _fill.linearStartY,
                linearEndX: _fill.linearEndX,
                linearEndY: _fill.linearEndY,
                radialCenterX: _fill.radialCenterX,
                radialCenterY: _fill.radialCenterY,
                radialRadius: _fill.radialRadius,
                imagePath: _fill.imagePath,
                imageFit: v,
              );
            });
          },
        ),
      ],
    );
  }
}

class _SaturationValueField extends StatelessWidget {
  const _SaturationValueField({
    required this.width,
    required this.height,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final double height;
  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _handle(d.localPosition),
      onPanUpdate: (d) => _handle(d.localPosition),
      child: CustomPaint(
        size: Size(width, height),
        painter: _SbPainter(hue: hue, cursorS: saturation, cursorV: value),
      ),
    );
  }

  void _handle(Offset local) {
    final s = (local.dx / width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / height).clamp(0.0, 1.0);
    onChanged(s, v);
  }
}

class _SbPainter extends CustomPainter {
  _SbPainter({
    required this.hue,
    required this.cursorS,
    required this.cursorV,
  });

  final double hue;
  final double cursorS;
  final double cursorV;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueFull = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(size.width, 0),
          [Colors.white, hueFull],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height),
          const Offset(0, 0),
          [Colors.black, const Color(0x00000000)],
        ),
    );
    final cx = cursorS * size.width;
    final cy = (1.0 - cursorV) * size.height;
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SbPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.cursorS != cursorS ||
        oldDelegate.cursorV != cursorV;
  }
}
