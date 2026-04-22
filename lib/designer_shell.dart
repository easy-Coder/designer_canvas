import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'designer_gesture_handler.dart';
import 'property_inspector.dart';
import 'tool_style_defaults.dart';

class DesignerShell extends StatelessWidget {
  const DesignerShell({
    super.key,
    required this.controller,
    required this.tool,
    required this.toolDefaults,
    required this.gestureConfig,
    required this.gestureHandler,
  });

  final InfiniteCanvasController controller;
  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;
  final InfiniteCanvasGestureConfig gestureConfig;
  final DesignerGestureHandler gestureHandler;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: _NodesPanel(controller: controller),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              InfiniteCanvasView(
                controller: controller,
                gestureHandler: gestureHandler,
                gestureConfig: gestureConfig,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: ValueListenableBuilder<CanvasTool>(
                        valueListenable: tool,
                        builder: (context, active, _) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final t in CanvasTool.values) ...[
                                  if (t != CanvasTool.values.first)
                                    const SizedBox(width: 6),
                                  FilterChip(
                                    avatar: Icon(_toolIcon(t), size: 18),
                                    label: Text(_toolLabel(t)),
                                    selected: active == t,
                                    onSelected: (_) => tool.value = t,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 280,
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: _PropertyPanelTitle(
              child: PropertyInspector(
                controller: controller,
                tool: tool,
                toolDefaults: toolDefaults,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _toolLabel(CanvasTool t) {
    return switch (t) {
      CanvasTool.select => 'Select',
      CanvasTool.rect => 'Rect',
      CanvasTool.circle => 'Circle',
      CanvasTool.triangle => 'Triangle',
      CanvasTool.line => 'Line',
      CanvasTool.text => 'Text',
    };
  }

  static IconData _toolIcon(CanvasTool t) {
    return switch (t) {
      CanvasTool.select => Icons.near_me_outlined,
      CanvasTool.rect => Icons.crop_square,
      CanvasTool.circle => Icons.circle_outlined,
      CanvasTool.triangle => Icons.change_history,
      CanvasTool.line => Icons.horizontal_rule,
      CanvasTool.text => Icons.text_fields,
    };
  }
}

class _NodesPanel extends StatelessWidget {
  const _NodesPanel({required this.controller});

  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const _PanelHeader(title: 'Nodes'),
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final nodes = controller.orderedNodes.reversed.toList();
              if (nodes.isEmpty) {
                return Center(
                  child: Text(
                    'No nodes yet',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final (quadId, node) = nodes[index];
                  final selected = controller.primaryQuadId == quadId;
                  return Card(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      dense: true,
                      title: Text(node.label),
                      subtitle: Text('id: $quadId'),
                      onTap: () => controller.selectSingle(quadId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PropertyPanelTitle extends StatelessWidget {
  const _PropertyPanelTitle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PanelHeader(title: 'Property Editor'),
        Expanded(child: child),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
