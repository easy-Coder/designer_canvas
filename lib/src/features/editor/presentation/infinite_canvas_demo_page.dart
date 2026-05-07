import 'dart:ui' as ui;

import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/node_codec.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_size_presets.dart';
import 'package:designer_canvas/src/features/editor/domain/node_entity.dart';
import 'package:designer_canvas/src/features/editor/domain/node_styles.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';
import 'package:designer_canvas/src/features/editor/domain/tool_style_defaults.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/canvas_input_config.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/canvas_select_gestures.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/designer_gesture_handler.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/pending_image_placement.dart';
import 'package:designer_canvas/src/features/editor/presentation/designer_shell.dart';
import 'package:designer_canvas/src/features/editor/presentation/editor_toolbar_metadata.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

class InfiniteCanvasDemoPage extends StatefulWidget {
  const InfiniteCanvasDemoPage({super.key});

  @override
  State<InfiniteCanvasDemoPage> createState() => _InfiniteCanvasDemoPageState();
}

class _InfiniteCanvasDemoPageState extends State<InfiniteCanvasDemoPage> {
  late final InfiniteCanvasController _controller;
  late final ValueNotifier<CanvasTool> _tool;
  late final DesignerCanvasInputConfig _gestureConfig;
  late final CanvasSelectGestures _selectGestures;
  late final DesignerGestureHandler _designerHandler;
  late final ValueNotifier<ToolStyleDefaults> _toolDefaults;
  late final ValueNotifier<FrameSizePreset> _frameSizePreset;
  late final FocusNode _canvasFocusNode;
  late final CanvasDocumentState _documentState;
  late final NodeCodec _nodeCodec;
  late final DocumentCanvasRenderer _renderer;
  late final ValueNotifier<Map<EditorToolGroupId, CanvasTool>> _lastUsedByGroup;
  late final ValueNotifier<PendingImagePlacement?> _pendingImagePlacement;

  @override
  void initState() {
    super.initState();
    _controller = InfiniteCanvasController(
      camera: Camera(
        viewportSize: const ui.Size(800, 600),
        position: ui.Offset.zero,
        zoomDouble: 0.05,
        minZoom: 0.01,
        maxZoom: 10.0,
      ),
      onNodeDoubleClick: _onNodeDoubleClick,
    );
    _toolDefaults = ValueNotifier(const ToolStyleDefaults());
    _frameSizePreset = ValueNotifier(FrameSizePreset.paper);
    _pendingImagePlacement = ValueNotifier(null);
    _nodeCodec = NodeCodec();
    _documentState = CanvasDocumentState(
      docId: 'local-doc',
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _renderer = DocumentCanvasRenderer(
      controller: _controller,
      documentState: _documentState,
      nodeCodec: _nodeCodec,
    );
    _canvasFocusNode = FocusNode(debugLabel: 'canvas-focus');

    // Seed two rectangles directly into the document. The renderer will
    // project them into runtime nodes once the listener fires below.
    _documentState.addNode(
      _nodeCodec.rectLikeEntity(
        id: _nodeCodec.newNodeId(),
        type: NodeEntityType.rect,
        name: 'Rectangle',
        rect: const ui.Rect.fromLTWH(-120, -80, 240, 160),
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF2E7D32)),
        ),
      ),
      notify: false,
    );
    _documentState.addNode(
      _nodeCodec.rectLikeEntity(
        id: _nodeCodec.newNodeId(),
        type: NodeEntityType.rect,
        name: 'Rectangle',
        rect: const ui.Rect.fromLTWH(80, 40, 100, 100),
        style: const RectNodeStyle(
          fill: FillStyleData(color: ui.Color(0xFF1565C0)),
        ),
      ),
      notify: false,
    );
    _renderer.rebuildFromDocument();

    _tool = ValueNotifier(CanvasTool.select);
    _lastUsedByGroup = ValueNotifier({
      for (final g in kEditorToolGroups) g.id: g.defaultTool,
    });
    _gestureConfig = const DesignerCanvasInputConfig(
      enableSelection: true,
      enableKeyboardShortcuts: false,
    );
    _selectGestures = CanvasSelectGestures(config: _gestureConfig);
    _designerHandler = DesignerGestureHandler(
      tool: _tool,
      toolDefaults: _toolDefaults,
      frameSizePreset: _frameSizePreset,
      documentState: _documentState,
      renderer: _renderer,
      nodeCodec: _nodeCodec,
      selectGestures: _selectGestures,
      gestureConfig: _gestureConfig,
      canvasFocusNode: _canvasFocusNode,
      onToolActivated: _setToolbarTool,
      pendingImagePlacement: _pendingImagePlacement,
    );
    _canvasFocusNode.addListener(() {
      _designerHandler.handleCanvasFocusChanged(
        _canvasFocusNode.hasFocus,
        _controller,
      );
    });
  }

  Future<PendingImagePlacement?> _pickImagePlacement() async {
    debugPrint('[image-tool] Image tool selected, opening file picker...');
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'png'],
      uniformTypeIdentifiers: <String>['public.jpeg', 'public.png'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return PendingImagePlacement(
      fileName: file.name,
      filePath: file.path,
      bytes: bytes,
      intrinsicWidth: image.width.toDouble(),
      intrinsicHeight: image.height.toDouble(),
    );
  }

  void _setToolbarTool(CanvasTool t) async {
    if (t == CanvasTool.image) {
      PendingImagePlacement? selected;
      try {
        selected = await _pickImagePlacement();
      } catch (_) {
        debugPrint('[image-tool] File picker threw an exception.');
        selected = null;
      }
      if (!mounted) {
        debugPrint('[image-tool] Widget unmounted before picker completed.');
        return;
      }
      if (selected == null) {
        debugPrint('[image-tool] No image selected (cancelled or failed).');
        return;
      }
      debugPrint(
        '[image-tool] Selected ${selected.fileName} '
        '(${selected.intrinsicWidth}x${selected.intrinsicHeight}).',
      );
      _pendingImagePlacement.value = selected;
    }
    debugPrint('[image-tool] Activating tool: ${t.name}');
    _tool.value = t;
    final gid = groupIdForTool(t);
    if (gid != null) {
      final m = Map<EditorToolGroupId, CanvasTool>.from(_lastUsedByGroup.value);
      m[gid] = t;
      _lastUsedByGroup.value = m;
    }
  }

  void _onNodeDoubleClick(int quadId, CanvasNode node) {
    if (node is TextNode) {
      _designerHandler.startEditing(quadId, node, _controller);
    }
  }

  @override
  void dispose() {
    _designerHandler.dispose();
    _renderer.dispose();
    _canvasFocusNode.dispose();
    _tool.dispose();
    _pendingImagePlacement.dispose();
    _lastUsedByGroup.dispose();
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
          gestureHandler: _designerHandler,
          canvasFocusNode: _canvasFocusNode,
          documentState: _documentState,
          renderer: _renderer,
          nodeCodec: _nodeCodec,
          lastUsedByGroup: _lastUsedByGroup,
          onToolbarToolSelected: _setToolbarTool,
        ),
      ),
    );
  }
}
