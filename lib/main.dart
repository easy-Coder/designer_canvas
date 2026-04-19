import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infinite_canvas/infinite_canvas.dart';

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
    _controller.addNode(_DemoRectNode(
      bounds: ui.Rect.fromLTWH(-120, -80, 240, 160),
      color: const ui.Color(0xFF2E7D32),
    ));
    _controller.addNode(_DemoRectNode(
      bounds: ui.Rect.fromLTWH(80, 40, 100, 100),
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
      appBar: AppBar(title: const Text('Infinite canvas')),
      body: InfiniteCanvasView(controller: _controller),
    );
  }
}

class _DemoRectNode extends CanvasNode {
  _DemoRectNode({required this.bounds, required this.color});

  @override
  final ui.Rect bounds;

  final ui.Color color;

  @override
  int get zIndex => 1;

  @override
  void draw(ui.Canvas canvas, CanvasPaintContext context) {
    final r = context.worldRectToViewport(bounds);
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(
      ui.RRect.fromRectXY(r, 8, 8),
      paint,
    );
    final stroke = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = context.hairlineStrokeWidth;
    canvas.drawRRect(ui.RRect.fromRectXY(r, 8, 8), stroke);
  }
}
