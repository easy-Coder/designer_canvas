import 'package:flutter/material.dart';

import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_size_presets.dart';
import 'package:designer_canvas/src/features/editor/presentation/editor_toolbar_metadata.dart';

/// Bottom-center Figma-like grouped tool bar with dropdowns and sticky last-used.
class FigmaEditorToolbar extends StatelessWidget {
  const FigmaEditorToolbar({
    super.key,
    required this.tool,
    required this.lastUsedByGroup,
    required this.frameSizePreset,
    required this.onToolSelected,
  });

  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<Map<EditorToolGroupId, CanvasTool>> lastUsedByGroup;
  final ValueNotifier<FrameSizePreset> frameSizePreset;
  final ValueChanged<CanvasTool> onToolSelected;

  static const _barBg = Color(0xFF2C2C2C);
  static const _activeBlue = Color(0xFF0D99FF);
  static const _iconOn = Color(0xFFE8EAED);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CanvasTool>(
      valueListenable: tool,
      builder: (context, activeTool, _) {
        return ValueListenableBuilder<Map<EditorToolGroupId, CanvasTool>>(
          valueListenable: lastUsedByGroup,
          builder: (context, lastMap, _) {
            return Material(
              elevation: 8,
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: _barBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF444444)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var gi = 0; gi < kEditorToolGroups.length; gi++) ...[
                        if (gi > 0)
                          Container(
                            width: 1,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: const Color(0xFF555555),
                          ),
                        _ToolGroupStrip(
                          definition: kEditorToolGroups[gi],
                          activeTool: activeTool,
                          lastMap: lastMap,
                          onPick: onToolSelected,
                          activeBlue: _activeBlue,
                          iconOn: _iconOn,
                        ),
                      ],
                      if (activeTool == CanvasTool.frame) ...[
                        const SizedBox(width: 8),
                        ValueListenableBuilder<FrameSizePreset>(
                          valueListenable: frameSizePreset,
                          builder: (context, preset, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Size',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: _iconOn),
                                ),
                                const SizedBox(width: 6),
                                for (final option in FrameSizePreset.values)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: preset == option
                                            ? _activeBlue
                                            : _iconOn,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        frameSizePreset.value = option;
                                      },
                                      child: Text(
                                        frameSizePresetSpecs[option]!.label,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ToolGroupStrip extends StatelessWidget {
  const _ToolGroupStrip({
    required this.definition,
    required this.activeTool,
    required this.lastMap,
    required this.onPick,
    required this.activeBlue,
    required this.iconOn,
  });

  final EditorToolGroupDefinition definition;
  final CanvasTool activeTool;
  final Map<EditorToolGroupId, CanvasTool> lastMap;
  final ValueChanged<CanvasTool> onPick;
  final Color activeBlue;
  final Color iconOn;

  EditorToolMenuItem _itemForTool(CanvasTool t) {
    return definition.items.firstWhere(
      (e) => e.tool == t,
      orElse: () => definition.items.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastUsed = lastMap[definition.id] ?? definition.defaultTool;
    final inGroup = definition.items.any((e) => e.tool == activeTool);
    final displayedTool = inGroup ? activeTool : lastUsed;
    final displayed = _itemForTool(displayedTool);
    final groupActive = inGroup;
    final showMenu = definition.items.length > 1;

    if (!showMenu) {
      final only = definition.items.single;
      final isActive = activeTool == only.tool;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPick(only.tool),
        child: Container(
          width: 40,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? activeBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(only.icon, size: 20, color: iconOn),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onPick(lastUsed),
          child: Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: groupActive ? activeBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(displayed.icon, size: 20, color: iconOn),
          ),
        ),
        MenuAnchor(
          menuChildren: [
            for (final item in definition.items)
              MenuItemButton(
                onPressed: () => onPick(item.tool),
                child: SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: activeTool == item.tool
                            ? Icon(Icons.check, size: 18, color: activeBlue)
                            : const SizedBox.shrink(),
                      ),
                      Icon(item.icon, size: 18, color: iconOn),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        item.shortcutHint,
                        style: const TextStyle(
                          color: Color(0xFF9AA0A6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          builder: (context, menuController, _) {
            final open = menuController.isOpen;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                if (open) {
                  menuController.close();
                } else {
                  menuController.open();
                }
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: open ? const Color(0xFF3D3D3D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.expand_more, size: 18, color: iconOn),
              ),
            );
          },
        ),
      ],
    );
  }
}
