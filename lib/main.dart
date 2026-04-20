import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'designer_gesture_handler.dart';
import 'rect_node.dart';
import 'text_node.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: InfiniteCanvasDemoPage(),
    );
  }
}

class InfiniteCanvasDemoPage extends StatefulWidget {
  const InfiniteCanvasDemoPage({super.key});

  @override
  State<InfiniteCanvasDemoPage> createState() => _InfiniteCanvasDemoPageState();
}

class _InfiniteCanvasDemoPageState extends State<InfiniteCanvasDemoPage> {
  late final InfiniteCanvasController _controller;
  late final ValueNotifier<CanvasTool> _tool;
  late final InfiniteCanvasGestureConfig _gestureConfig;
  late final DefaultInfiniteCanvasGestureHandler _defaultHandler;
  late final DesignerGestureHandler _designerHandler;

  @override
  void initState() {
    super.initState();
    const world = ui.Rect.fromLTWH(-10000, -10000, 20000, 20000);
    _controller = InfiniteCanvasController(
      worldBounds: world,
      onNodeDoubleClick: _onNodeDoubleClick,
    );
    _controller.camera.changeSize(const ui.Size(800, 600));
    _controller.camera.moveTo(ui.Offset.zero);
    _controller.camera.setZoomDouble(0.35);
    _controller.addNode(RectNode(
      center: ui.Offset.zero,
      width: 240,
      height: 160,
      color: const ui.Color(0xFF2E7D32),
    ));
    _controller.addNode(RectNode(
      center: const ui.Offset(130, 90),
      width: 100,
      height: 100,
      color: const ui.Color(0xFF1565C0),
    ));

    _tool = ValueNotifier(CanvasTool.select);
    _gestureConfig = const InfiniteCanvasGestureConfig(
      enableSelection: true,
      enableKeyboardShortcuts: false,
    );
    _defaultHandler = DefaultInfiniteCanvasGestureHandler(
      config: _gestureConfig,
    );
    _designerHandler = DesignerGestureHandler(
      tool: _tool,
      delegate: _defaultHandler,
      gestureConfig: _gestureConfig,
    );
  }

  void _onNodeDoubleClick(int quadId, CanvasNode node) {
    if (node is TextNode) {
      _designerHandler.startEditing(quadId, node);
    }
  }

  @override
  void dispose() {
    _tool.dispose();
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            elevation: 2,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ValueListenableBuilder<CanvasTool>(
                  valueListenable: _tool,
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
                              onSelected: (_) {
                                _tool.value = t;
                              },
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
          Expanded(
            child: InfiniteCanvasView(
              controller: _controller,
              gestureHandler: _designerHandler,
              gestureConfig: _gestureConfig,
            ),
          ),
        ],
      ),
    );
  }
}
