import 'dart:ui' as ui;

/// Shared layout for painting and hit-testing frame titles in viewport space.
final class FrameTitleLayout {
  FrameTitleLayout._();

  static const double fontSizePx = 14;
  static const double padX = 6;
  static const double padY = 2;
  static const double cornerRadius = 4;
  // Negative moves the title further above the frame edge.
  static const double overlapY = -6;

  static ui.Paragraph _paragraphFor(String text, {double? maxWidth}) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSizePx,
        fontWeight: ui.FontWeight.w600,
        maxLines: 1,
        ellipsis: '…',
      ),
    )..pushStyle(
        ui.TextStyle(color: const ui.Color(0xFF1D1D1D)),
      );
    pb.addText(text);
    final p = pb.build();
    p.layout(ui.ParagraphConstraints(width: maxWidth ?? double.infinity));
    return p;
  }

  /// Computes the title background rect in viewport space for a frame.
  static ui.Rect titleRectForFrameRect(ui.Rect frameViewportRect) {
    // Title sits on top of the frame edge (slight overlap).
    final left = frameViewportRect.left + padX;
    final h = fontSizePx + padY * 2;
    final top = frameViewportRect.top - h + overlapY;
    // Width/height are driven by the laid-out paragraph; caller can expand.
    return ui.Rect.fromLTWH(left, top, 10, h);
  }

  static ({
    ui.Paragraph paragraph,
    ui.Rect backgroundRect,
    ui.Offset paragraphOffset
  }) layoutForFrame({
    required ui.Rect frameViewportRect,
    required String label,
  }) {
    final maxW = (frameViewportRect.width - padX * 2).clamp(24.0, 1e9);
    final paragraph = _paragraphFor(label, maxWidth: maxW);
    final base = titleRectForFrameRect(frameViewportRect);
    final bg = ui.Rect.fromLTWH(
      base.left,
      base.top,
      (paragraph.maxIntrinsicWidth + padX * 2).clamp(24.0, maxW),
      paragraph.height + padY * 2,
    );
    final off = ui.Offset(bg.left + padX, bg.top + padY);
    return (paragraph: paragraph, backgroundRect: bg, paragraphOffset: off);
  }
}

