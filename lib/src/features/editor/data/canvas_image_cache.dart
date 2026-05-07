import 'dart:io';
import 'dart:ui' as ui;

/// Loads and caches [ui.Image] instances by filesystem path for canvas paints.
///
/// Used by [ImageNode] and image [FillStyleData] fills so decode logic lives
/// in one place.
class CanvasImageCache {
  CanvasImageCache._();
  static final CanvasImageCache instance = CanvasImageCache._();

  final Map<String, ui.Image> _byPath = <String, ui.Image>{};
  final Set<String> _failed = <String>{};
  final Map<String, Future<void>> _loading = <String, Future<void>>{};

  ui.Image? tryGet(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    return _byPath[trimmed];
  }

  bool didFail(String path) => _failed.contains(path.trim());

  /// Starts loading if needed; when complete, schedules a frame so painters
  /// can pick up the image.
  void ensureLoaded(String path) {
    final p = path.trim();
    if (p.isEmpty) return;
    if (_byPath.containsKey(p) || _failed.contains(p) || _loading.containsKey(p)) {
      return;
    }
    _loading[p] = _load(p);
  }

  Future<void> _load(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        _failed.add(path);
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _byPath[path] = frame.image;
      _failed.remove(path);
      ui.PlatformDispatcher.instance.scheduleFrame();
    } catch (_) {
      _failed.add(path);
    } finally {
      _loading.remove(path);
    }
  }

  void clearFailure(String path) {
    _failed.remove(path.trim());
  }
}
