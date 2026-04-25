import 'dart:ui' as ui;

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/node_codec.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_size_presets.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';
import 'package:designer_canvas/src/features/editor/domain/tool_style_defaults.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/designer_gesture_handler.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/document_reducer.dart';
import 'package:designer_canvas/src/features/editor/presentation/designer_shell.dart';
import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

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
  late final CanvasDocumentState _documentState;
  late final NodeCodec _nodeCodec;
  late final RuntimeIndexBridge _runtimeBridge;
  late final DocumentReducer _documentReducer;

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
    _nodeCodec = NodeCodec();
    _documentState = CanvasDocumentState(
      docId: 'local-doc',
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _runtimeBridge = RuntimeIndexBridge(
      controller: _controller,
      documentState: _documentState,
      nodeCodec: _nodeCodec,
    );
    _documentReducer = DocumentReducer(
      documentState: _documentState,
      runtimeBridge: _runtimeBridge,
    );
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
    final seedNodes = <RectNode>[
      RectNode(
        center: ui.Offset.zero,
        width: 240,
        height: 160,
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF2E7D32)),
        ),
      ),
      RectNode(
        center: const ui.Offset(130, 90),
        width: 100,
        height: 100,
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF1565C0)),
        ),
      ),
    ];
    for (final seed in seedNodes) {
      _documentState.upsertNode(_nodeCodec.entityFromNode(seed), notify: false);
    }
    _documentState.emitChange();
    _runtimeBridge.rebuildFromDocument();

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
      documentState: _documentState,
      runtimeBridge: _runtimeBridge,
      documentReducer: _documentReducer,
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
    _documentState.dispose();
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
          documentState: _documentState,
          runtimeBridge: _runtimeBridge,
        ),
      ),
    );
  }
}
