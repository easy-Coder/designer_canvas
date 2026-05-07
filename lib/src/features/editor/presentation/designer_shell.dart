import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'package:designer_canvas/src/features/editor/domain/canvas_tool.dart';
import 'package:designer_canvas/src/features/editor/domain/frame_size_presets.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/arrow_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/circle_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/frame_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/image_placeholder_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/line_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/polygon_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/rect_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/star_node.dart';
import 'package:designer_canvas/src/features/editor/domain/nodes/text_node.dart';

import 'package:designer_canvas/src/features/editor/domain/tool_style_defaults.dart';
import 'package:designer_canvas/src/features/editor/data/canvas_document_state.dart';
import 'package:designer_canvas/src/features/editor/data/runtime_index_bridge.dart';
import 'package:designer_canvas/src/features/editor/presentation/controller/designer_gesture_handler.dart';
import 'package:designer_canvas/src/features/editor/presentation/editor_toolbar_metadata.dart';
import 'package:designer_canvas/src/features/editor/presentation/property_inspector.dart';
import 'package:designer_canvas/src/features/editor/presentation/widgets/figma_editor_toolbar.dart';

class DesignerShell extends StatelessWidget {
  const DesignerShell({
    super.key,
    required this.controller,
    required this.tool,
    required this.toolDefaults,
    required this.frameSizePreset,
    required this.gestureHandler,
    required this.canvasFocusNode,
    required this.documentState,
    required this.runtimeBridge,
    required this.lastUsedByGroup,
    required this.onToolbarToolSelected,
  });

  final InfiniteCanvasController controller;
  final ValueNotifier<CanvasTool> tool;
  final ValueNotifier<ToolStyleDefaults> toolDefaults;
  final ValueNotifier<FrameSizePreset> frameSizePreset;
  final DesignerGestureHandler gestureHandler;
  final FocusNode canvasFocusNode;
  final CanvasDocumentState documentState;
  final RuntimeIndexBridge runtimeBridge;
  final ValueNotifier<Map<EditorToolGroupId, CanvasTool>> lastUsedByGroup;
  final ValueChanged<CanvasTool> onToolbarToolSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: ColoredBox(
            color: Colors.white,
            child: _LayersPanel(
              controller: controller,
              documentState: documentState,
              runtimeBridge: runtimeBridge,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Focus(
                focusNode: canvasFocusNode,
                onKeyEvent: (node, event) {
                  if (gestureHandler.handleKeyEvent(event, controller)) {
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: InfiniteCanvasView(
                  controller: controller,
                  onPointerEvent: (e) =>
                      gestureHandler.handlePointerEvent(e, controller),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FigmaEditorToolbar(
                    tool: tool,
                    lastUsedByGroup: lastUsedByGroup,
                    frameSizePreset: frameSizePreset,
                    onToolSelected: onToolbarToolSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 300,
          child: Theme(
            data: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.dark(
                surface: const Color(0xFF252525),
                onSurface: const Color(0xFFE8E8E8),
                primary: const Color(0xFF4A9EFF),
                onPrimary: Colors.white,
              ),
              dividerColor: const Color(0xFF3D3D3D),
              useMaterial3: true,
            ),
            child: ColoredBox(
              color: const Color(0xFF252525),
              child: _PropertyPanelTitle(
                child: PropertyInspector(
                  controller: controller,
                  tool: tool,
                  toolDefaults: toolDefaults,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LayersPanel extends StatefulWidget {
  const _LayersPanel({
    required this.controller,
    required this.documentState,
    required this.runtimeBridge,
  });

  final InfiniteCanvasController controller;
  final CanvasDocumentState documentState;
  final RuntimeIndexBridge runtimeBridge;

  @override
  State<_LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<_LayersPanel> {
  final FocusNode _panelFocusNode = FocusNode(debugLabel: 'layers-panel-focus');
  final FocusNode _renameFocusNode = FocusNode(
    debugLabel: 'layers-rename-focus',
  );
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();

  int? _rangeAnchorQuadId;
  int? _renamingQuadId;
  String? _renameSnapshot;
  String _searchQuery = '';

  InfiniteCanvasController get _controller => widget.controller;

  List<_LayerListRow> get _rows {
    final ordered = _controller.orderedNodes.reversed.toList(growable: false);
    final rankByQuadId = <int, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i].$1: i,
    };
    final rowsByNodeId = <String, _LayerListRow>{};
    final rowsByQuadId = <int, _LayerListRow>{};
    for (final (quadId, node) in ordered) {
      final nodeId = widget.runtimeBridge.nodeIdForQuadId(quadId);
      if (nodeId == null) {
        rowsByQuadId[quadId] = _LayerListRow(
          quadId: quadId,
          node: node,
          nodeId: null,
          parentNodeId: null,
          depth: 0,
          hasChildren: false,
        );
        continue;
      }
      rowsByNodeId[nodeId] = _LayerListRow(
        quadId: quadId,
        node: node,
        nodeId: nodeId,
        parentNodeId: widget.documentState.parentOf(nodeId),
        depth: 0,
        hasChildren: widget.documentState.childrenOf(nodeId).isNotEmpty,
      );
    }

    final orderedRows = <_LayerListRow>[];
    final visited = <String>{};
    final rootNodeIds = <String>[];

    for (final nodeId in widget.documentState.rootOrder) {
      if (rowsByNodeId.containsKey(nodeId)) {
        rootNodeIds.add(nodeId);
      }
    }
    for (final nodeId in rowsByNodeId.keys) {
      final parentId = widget.documentState.parentOf(nodeId);
      if (parentId == null || !rowsByNodeId.containsKey(parentId)) {
        if (!rootNodeIds.contains(nodeId)) {
          rootNodeIds.add(nodeId);
        }
      }
    }
    rootNodeIds.sort((a, b) {
      final qa = rowsByNodeId[a]?.quadId;
      final qb = rowsByNodeId[b]?.quadId;
      final ra = qa == null ? 1 << 30 : (rankByQuadId[qa] ?? (1 << 30));
      final rb = qb == null ? 1 << 30 : (rankByQuadId[qb] ?? (1 << 30));
      return ra.compareTo(rb);
    });

    void appendTree(String nodeId, int depth) {
      if (visited.contains(nodeId)) return;
      final row = rowsByNodeId[nodeId];
      if (row == null) return;
      visited.add(nodeId);
      orderedRows.add(row.copyWith(depth: depth));
      final childIds = widget.documentState
          .childrenOf(nodeId)
          .where(rowsByNodeId.containsKey)
          .toList(growable: false);
      childIds.sort((a, b) {
        final qa = rowsByNodeId[a]?.quadId;
        final qb = rowsByNodeId[b]?.quadId;
        final ra = qa == null ? 1 << 30 : (rankByQuadId[qa] ?? (1 << 30));
        final rb = qb == null ? 1 << 30 : (rankByQuadId[qb] ?? (1 << 30));
        return ra.compareTo(rb);
      });
      for (final childId in childIds) {
        appendTree(childId, depth + 1);
      }
    }

    for (final rootNodeId in rootNodeIds) {
      appendTree(rootNodeId, 0);
    }

    for (final entry in rowsByNodeId.entries) {
      if (!visited.contains(entry.key)) {
        orderedRows.add(entry.value);
      }
    }

    for (final entry in rowsByQuadId.entries) {
      orderedRows.add(entry.value);
    }
    return orderedRows;
  }

  List<_LayerListRow> get _visibleRows {
    final rows = _rows;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return rows;

    final byNodeId = <String, _LayerListRow>{};
    for (final row in rows) {
      final nodeId = row.nodeId;
      if (nodeId != null) {
        byNodeId[nodeId] = row;
      }
    }

    final keepNodeIds = <String>{};
    for (final row in rows) {
      if (!row.node.label.toLowerCase().contains(query)) continue;
      final nodeId = row.nodeId;
      if (nodeId == null) continue;
      keepNodeIds.add(nodeId);
      var parentId = row.parentNodeId;
      while (parentId != null && byNodeId.containsKey(parentId)) {
        if (!keepNodeIds.add(parentId)) break;
        parentId = byNodeId[parentId]?.parentNodeId;
      }
    }

    return rows
        .where((row) {
          final nodeId = row.nodeId;
          if (nodeId == null) {
            return row.node.label.toLowerCase().contains(query);
          }
          return keepNodeIds.contains(nodeId);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _searchQuery) return;
      setState(() {
        _searchQuery = next;
      });
    });
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    _renameFocusNode.dispose();
    _searchController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _requestPanelFocus() {
    if (!_panelFocusNode.hasFocus) {
      _panelFocusNode.requestFocus();
    }
  }

  bool _isShiftPressed() => HardwareKeyboard.instance.isShiftPressed;

  int _rowIndexByQuadId(List<_LayerListRow> rows, int? quadId) {
    if (quadId == null) return -1;
    return rows.indexWhere((entry) => entry.quadId == quadId);
  }

  void _setSingleSelection(int quadId) {
    _controller.selectSingle(quadId);
    _rangeAnchorQuadId = quadId;
  }

  void _setRangeSelection(List<_LayerListRow> rows, int targetIndex) {
    if (rows.isEmpty || targetIndex < 0 || targetIndex >= rows.length) return;
    final primary = _controller.primaryQuadId;
    if (primary == null) {
      _setSingleSelection(rows[targetIndex].quadId);
      return;
    }
    _rangeAnchorQuadId ??= primary;
    final anchorIndex = _rowIndexByQuadId(rows, _rangeAnchorQuadId);
    if (anchorIndex == -1) {
      _rangeAnchorQuadId = primary;
    }
    final safeAnchorIndex = _rowIndexByQuadId(rows, _rangeAnchorQuadId);
    if (safeAnchorIndex == -1) {
      _setSingleSelection(rows[targetIndex].quadId);
      return;
    }
    final start = safeAnchorIndex < targetIndex ? safeAnchorIndex : targetIndex;
    final end = safeAnchorIndex > targetIndex ? safeAnchorIndex : targetIndex;
    final ids = <int>{for (var i = start; i <= end; i++) rows[i].quadId};
    _controller.setSelection(ids, primary: rows[targetIndex].quadId);
  }

  void _moveSelectionBy(int delta, {required bool extendRange}) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentPrimary = _controller.primaryQuadId;
    final currentIndex = _rowIndexByQuadId(rows, currentPrimary);
    final safeCurrentIndex = currentIndex == -1 ? 0 : currentIndex;
    final nextIndex = (safeCurrentIndex + delta).clamp(0, rows.length - 1);
    if (extendRange) {
      _setRangeSelection(rows, nextIndex);
      return;
    }
    _setSingleSelection(rows[nextIndex].quadId);
  }

  void _startRename(int quadId, String currentLabel) {
    _requestPanelFocus();
    _renamingQuadId = quadId;
    _renameSnapshot = currentLabel;
    _renameController
      ..text = currentLabel
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: currentLabel.length,
      );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _renameFocusNode.requestFocus();
      }
    });
  }

  void _finishRename({required bool commit}) {
    final quadId = _renamingQuadId;
    if (quadId == null) return;
    final node = _controller.lookupNode(quadId);
    final fallbackLabel = _renameSnapshot ?? '';
    final next = _renameController.text.trim();
    if (node != null && commit) {
      node.label = next.isEmpty ? fallbackLabel : next;
      _controller.invalidate();
    }
    _renamingQuadId = null;
    _renameSnapshot = null;
    _renameController.clear();
    setState(() {});
    _requestPanelFocus();
  }

  void _onRowTap(int quadId) {
    _requestPanelFocus();
    if (_isShiftPressed()) {
      final rows = _visibleRows;
      final targetIndex = _rowIndexByQuadId(rows, quadId);
      if (targetIndex != -1) {
        _setRangeSelection(rows, targetIndex);
      }
      return;
    }
    _setSingleSelection(quadId);
  }

  bool _handlePanelKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_renamingQuadId != null) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelectionBy(-1, extendRange: _isShiftPressed());
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelectionBy(1, extendRange: _isShiftPressed());
      return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.f2) {
      final primary = _controller.primaryQuadId;
      if (primary != null && _controller.selectedQuadIds.length == 1) {
        final node = _controller.lookupNode(primary);
        if (node != null) {
          _startRename(primary, node.label);
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      focusNode: _panelFocusNode,
      onKeyEvent: (_, event) => _handlePanelKey(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Column(
        children: [
          const _PanelHeader(title: 'Layers', backgroundColor: Colors.white),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search layers',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _searchController.clear(),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final rows = _visibleRows;
                if (_renamingQuadId != null &&
                    !rows.any((row) => row.quadId == _renamingQuadId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _finishRename(commit: true);
                    }
                  });
                }
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.trim().isEmpty
                          ? 'No layers yet'
                          : 'No matching layers',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, thickness: .5),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final quadId = row.quadId;
                    final node = row.node;
                    final isSelected = _controller.selectedQuadIds.contains(
                      quadId,
                    );
                    final isPrimary = _controller.primaryQuadId == quadId;
                    final isRenaming = _renamingQuadId == quadId;
                    return InkWell(
                      onTap: () => _onRowTap(quadId),
                      onDoubleTap: () {
                        _setSingleSelection(quadId);
                        _startRename(quadId, node.label);
                      },
                      child: Container(
                        height: 36,
                        color: isSelected
                            ? const Color(0xFFE8F0FE)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            SizedBox(width: row.depth * 14),
                            SizedBox(
                              width: 14,
                              child: row.hasChildren
                                  ? const Icon(
                                      Icons.expand_more,
                                      size: 14,
                                      color: Color(0xFF7A7D81),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _layerIcon(node),
                              size: 14,
                              color: const Color(0xFF5F6368),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: isRenaming
                                  ? Focus(
                                      onKeyEvent: (_, event) {
                                        if (event is! KeyDownEvent) {
                                          return KeyEventResult.ignored;
                                        }
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.escape) {
                                          _finishRename(commit: false);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: TextField(
                                        controller: _renameController,
                                        focusNode: _renameFocusNode,
                                        autofocus: true,
                                        style: theme.textTheme.bodyMedium,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (_) =>
                                            _finishRename(commit: true),
                                        onTapOutside: (_) =>
                                            _finishRename(commit: true),
                                      ),
                                    )
                                  : Text(
                                      node.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF37474F),
                                            fontWeight: isPrimary
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
  const _PanelHeader({required this.title, this.backgroundColor});

  final String title;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
    );
  }
}

class _LayerListRow {
  const _LayerListRow({
    required this.quadId,
    required this.node,
    required this.nodeId,
    required this.parentNodeId,
    required this.depth,
    required this.hasChildren,
  });

  final int quadId;
  final CanvasNode node;
  final String? nodeId;
  final String? parentNodeId;
  final int depth;
  final bool hasChildren;

  _LayerListRow copyWith({int? depth}) {
    return _LayerListRow(
      quadId: quadId,
      node: node,
      nodeId: nodeId,
      parentNodeId: parentNodeId,
      depth: depth ?? this.depth,
      hasChildren: hasChildren,
    );
  }
}

IconData _layerIcon(CanvasNode node) {
  if (node is FrameNode) return Icons.grid_view_outlined;
  if (node is PolygonNode) return Icons.hexagon_outlined;
  if (node is StarNode) return Icons.star_outline;
  if (node is ImageNode) return Icons.image_outlined;
  if (node is ArrowNode) return Icons.north_east;
  if (node is RectNode) return Icons.crop_square_outlined;
  if (node is CircleNode) return Icons.circle_outlined;

  if (node is LineNode) return Icons.horizontal_rule;
  if (node is TextNode) return Icons.text_fields;
  return Icons.square_outlined;
}
