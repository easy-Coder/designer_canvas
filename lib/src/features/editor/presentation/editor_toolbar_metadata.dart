import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';

/// Logical groups for the Figma-style bottom toolbar.
enum EditorToolGroupId { select, frame, shapes, pen, text, assets }

/// One entry in a group dropdown (or single-slot group).
class EditorToolMenuItem {
  const EditorToolMenuItem({
    required this.tool,
    required this.label,
    required this.icon,
    required this.shortcutHint,
    this.activator,
  });

  final CanvasTool tool;
  final String label;
  final IconData icon;

  /// Single-letter or short hint shown in the menu (not OS-specific).
  final String shortcutHint;

  /// Optional single-key activator (no modifiers). Used for keyboard shortcuts.
  final SingleActivator? activator;
}

class EditorToolGroupDefinition {
  const EditorToolGroupDefinition({
    required this.id,
    required this.items,
    required this.defaultTool,
  });

  final EditorToolGroupId id;
  final List<EditorToolMenuItem> items;
  final CanvasTool defaultTool;

  CanvasTool get initialLastUsed => defaultTool;
}

/// Canonical toolbar layout: icons, labels, groups, and shortcut metadata.
final List<EditorToolGroupDefinition> kEditorToolGroups = [
  EditorToolGroupDefinition(
    id: EditorToolGroupId.select,
    defaultTool: CanvasTool.select,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.select,
        label: 'Select',
        icon: Icons.near_me_outlined,
        shortcutHint: 'V',
        activator: const SingleActivator(LogicalKeyboardKey.keyV),
      ),
    ],
  ),
  EditorToolGroupDefinition(
    id: EditorToolGroupId.frame,
    defaultTool: CanvasTool.frame,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.frame,
        label: 'Frame',
        icon: Icons.grid_view_outlined,
        shortcutHint: 'F',
        activator: const SingleActivator(LogicalKeyboardKey.keyF),
      ),
    ],
  ),
  EditorToolGroupDefinition(
    id: EditorToolGroupId.shapes,
    defaultTool: CanvasTool.rect,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.rect,
        label: 'Rectangle',
        icon: Icons.crop_square_outlined,
        shortcutHint: 'R',
        activator: const SingleActivator(LogicalKeyboardKey.keyR),
      ),
      EditorToolMenuItem(
        tool: CanvasTool.line,
        label: 'Line',
        icon: Icons.horizontal_rule,
        shortcutHint: 'L',
        activator: const SingleActivator(LogicalKeyboardKey.keyL),
      ),
      EditorToolMenuItem(
        tool: CanvasTool.arrow,
        label: 'Arrow',
        icon: Icons.north_east,
        shortcutHint: 'A',
        activator: const SingleActivator(LogicalKeyboardKey.keyA),
      ),
      EditorToolMenuItem(
        tool: CanvasTool.circle,
        label: 'Ellipse',
        icon: Icons.circle_outlined,
        shortcutHint: 'O',
        activator: const SingleActivator(LogicalKeyboardKey.keyO),
      ),
      EditorToolMenuItem(
        tool: CanvasTool.polygon,
        label: 'Polygon',
        icon: Icons.hexagon_outlined,
        shortcutHint: 'Y',
        activator: const SingleActivator(LogicalKeyboardKey.keyY),
      ),
      EditorToolMenuItem(
        tool: CanvasTool.star,
        label: 'Star',
        icon: Icons.star_outline,
        shortcutHint: 'S',
        activator: const SingleActivator(LogicalKeyboardKey.keyS),
      ),
    ],
  ),
  EditorToolGroupDefinition(
    id: EditorToolGroupId.pen,
    defaultTool: CanvasTool.pen,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.pen,
        label: 'Pen',
        icon: Icons.gesture_outlined,
        shortcutHint: 'P',
        activator: const SingleActivator(LogicalKeyboardKey.keyP),
      ),
    ],
  ),
  EditorToolGroupDefinition(
    id: EditorToolGroupId.text,
    defaultTool: CanvasTool.text,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.text,
        label: 'Text',
        icon: Icons.text_fields,
        shortcutHint: 'T',
        activator: const SingleActivator(LogicalKeyboardKey.keyT),
      ),
    ],
  ),
  EditorToolGroupDefinition(
    id: EditorToolGroupId.assets,
    defaultTool: CanvasTool.image,
    items: [
      EditorToolMenuItem(
        tool: CanvasTool.image,
        label: 'Image',
        icon: Icons.image_outlined,
        shortcutHint: 'K',
        activator: const SingleActivator(LogicalKeyboardKey.keyK),
      ),
    ],
  ),
];

EditorToolGroupId? groupIdForTool(CanvasTool tool) {
  for (final g in kEditorToolGroups) {
    if (g.items.any((e) => e.tool == tool)) return g.id;
  }
  return null;
}

EditorToolMenuItem? menuItemForTool(CanvasTool tool) {
  for (final g in kEditorToolGroups) {
    for (final item in g.items) {
      if (item.tool == tool) return item;
    }
  }
  return null;
}

/// Maps a key event to a tool when no modifiers (except shift for future) are required.
CanvasTool? toolForKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return null;
  final key = event.logicalKey;
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final meta = HardwareKeyboard.instance.isMetaPressed;
  final alt = HardwareKeyboard.instance.isAltPressed;
  final control = HardwareKeyboard.instance.isControlPressed;
  if (meta || alt || control) return null;
  if (shift) return null;

  for (final g in kEditorToolGroups) {
    for (final item in g.items) {
      final a = item.activator;
      if (a == null) continue;
      if (a.trigger == key) return item.tool;
    }
  }
  return null;
}
