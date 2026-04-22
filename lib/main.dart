import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'designer_shell.dart';
import 'designer_gesture_handler.dart';
import 'node_styles.dart';
import 'rect_node.dart';
import 'text_node.dart';
import 'tool_style_defaults.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE65100)),
      ),
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
  late final ValueNotifier<ToolStyleDefaults> _toolDefaults;

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
    _toolDefaults = ValueNotifier(const ToolStyleDefaults());
    _controller.addNode(RectNode(
      center: ui.Offset.zero,
      width: 240,
      height: 160,
      style: const RectNodeStyle(
        fill: FillStyleData(color: ui.Color(0xFF2E7D32)),
      ),
    ));
    _controller.addNode(RectNode(
      center: const ui.Offset(130, 90),
      width: 100,
      height: 100,
      style: const RectNodeStyle(
        fill: FillStyleData(color: ui.Color(0xFF1565C0)),
      ),
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
      toolDefaults: _toolDefaults,
      delegate: _defaultHandler,
      gestureConfig: _gestureConfig,
    );
  }

  void _onNodeDoubleClick(int quadId, CanvasNode node) {
    if (node is TextNode) {
      _designerHandler.startEditing(quadId, node, _controller);
    }
  }

  @override
  void dispose() {
    _tool.dispose();
    _toolDefaults.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DesignerShell(
          controller: _controller,
          tool: _tool,
          toolDefaults: _toolDefaults,
          gestureConfig: _gestureConfig,
          gestureHandler: _designerHandler,
        ),
      ),
    );
  }
}
