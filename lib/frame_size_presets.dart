import 'dart:ui' as ui;

enum FrameSizePreset { paper, phone, tablet, laptop }

class FrameSizePresetSpec {
  const FrameSizePresetSpec({
    required this.label,
    required this.description,
    required this.size,
  });

  final String label;
  final String description;
  final ui.Size size;
}

const Map<FrameSizePreset, FrameSizePresetSpec> frameSizePresetSpecs = {
  FrameSizePreset.paper: FrameSizePresetSpec(
    label: 'Paper',
    description: 'A4',
    size: ui.Size(794, 1123),
  ),
  FrameSizePreset.phone: FrameSizePresetSpec(
    label: 'Phone',
    description: '390 x 844',
    size: ui.Size(390, 844),
  ),
  FrameSizePreset.tablet: FrameSizePresetSpec(
    label: 'Tablet',
    description: '834 x 1194',
    size: ui.Size(834, 1194),
  ),
  FrameSizePreset.laptop: FrameSizePresetSpec(
    label: 'Laptop',
    description: '1440 x 900',
    size: ui.Size(1440, 900),
  ),
};
