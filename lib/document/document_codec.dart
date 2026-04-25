import 'canvas_document_state.dart';

class DocumentCodec {
  const DocumentCodec({this.schemaVersion = 1});

  final int schemaVersion;

  Map<String, dynamic> toJson(CanvasDocumentState document) {
    final json = document.toJson();
    json['schemaVersion'] = schemaVersion;
    return json;
  }

  CanvasDocumentState fromJson(Map<String, dynamic> json) {
    final rawVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (rawVersion > schemaVersion) {
      throw StateError(
        'Unsupported document schema version: $rawVersion > $schemaVersion',
      );
    }
    return CanvasDocumentState.fromJson(json);
  }
}
