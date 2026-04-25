import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'canvas_tool.dart';
import 'designer_shell.dart';
import 'designer_gesture_handler.dart';
import 'frame_size_presets.dart';
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

class _InfiniteCanvasDemoPageState extends State<InfiniteCanvasDemoPage>
    with SingleTickerProviderStateMixin {
  late final InfiniteCanvasController _controller;
  late final ValueNotifier<CanvasTool> _tool;
  late final InfiniteCanvasGestureConfig _gestureConfig;
  late final DefaultInfiniteCanvasGestureHandler _defaultHandler;
  late final DesignerGestureHandler _designerHandler;
  late final ValueNotifier<ToolStyleDefaults> _toolDefaults;
  late final ValueNotifier<FrameSizePreset> _frameSizePreset;
  late final FocusNode _canvasFocusNode;
  late final AnimationController _cursorBlinkController;
  late final ValueNotifier<bool> _cursorVisible;

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
    _frameSizePreset = ValueNotifier(FrameSizePreset.paper);
    _canvasFocusNode = FocusNode(debugLabel: 'canvas-focus');
    _cursorVisible = ValueNotifier(true);
    _cursorBlinkController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 550),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _cursorBlinkController.reverse();
            } else if (status == AnimationStatus.dismissed) {
              _cursorBlinkController.forward();
            }
          })
          ..addListener(() {
            final nextVisible = _cursorBlinkController.value > 0.5;
            if (_cursorVisible.value != nextVisible) {
              _cursorVisible.value = nextVisible;
              _designerHandler.updateEditingCaretVisibility(_controller);
            }
          });
    _controller.addNode(
      RectNode(
        center: ui.Offset.zero,
        width: 240,
        height: 160,
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF2E7D32)),
        ),
      ),
    );
    _controller.addNode(
      RectNode(
        center: const ui.Offset(130, 90),
        width: 100,
        height: 100,
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF1565C0)),
        ),
      ),
    );

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
      frameSizePreset: _frameSizePreset,
      delegate: _defaultHandler,
      gestureConfig: _gestureConfig,
      canvasFocusNode: _canvasFocusNode,
      startCursorBlink: () {
        _cursorVisible.value = true;
        _cursorBlinkController
          ..stop()
          ..value = 1
          ..reverse();
      },
      stopCursorBlink: () {
        _cursorBlinkController.stop();
        _cursorVisible.value = false;
      },
      isCursorVisible: () => _cursorVisible.value,
    );
    _canvasFocusNode.addListener(() {
      _designerHandler.handleCanvasFocusChanged(
        _canvasFocusNode.hasFocus,
        _controller,
      );
    });
  }

  void _onNodeDoubleClick(int quadId, CanvasNode node) {
    if (node is TextNode) {
      _designerHandler.startEditing(quadId, node, _controller);
    }
  }

  @override
  void dispose() {
    _designerHandler.dispose();
    _cursorBlinkController.dispose();
    _cursorVisible.dispose();
    _canvasFocusNode.dispose();
    _tool.dispose();
    _toolDefaults.dispose();
    _frameSizePreset.dispose();
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
          frameSizePreset: _frameSizePreset,
          gestureConfig: _gestureConfig,
          gestureHandler: _designerHandler,
          canvasFocusNode: _canvasFocusNode,
        ),
      ),
    );
  }
}
