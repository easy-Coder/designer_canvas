import 'dart:typed_data';

class PendingImagePlacement {
  const PendingImagePlacement({
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.intrinsicWidth,
    required this.intrinsicHeight,
  });

  final String fileName;
  final String filePath;
  final Uint8List bytes;
  final double intrinsicWidth;
  final double intrinsicHeight;
}
