import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

import 'rect_node.dart';

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

  @override
  void initState() {
    super.initState();
    const world = ui.Rect.fromLTWH(-10000, -10000, 20000, 20000);
    _controller = InfiniteCanvasController(worldBounds: world);
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Infinite canvas')),
      body: InfiniteCanvasView(
        controller: _controller,
        gestureConfig: const InfiniteCanvasGestureConfig(
          enableSelection: true,
        ),
      ),
    );
  }
}
