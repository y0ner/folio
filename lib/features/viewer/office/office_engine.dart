import '../../../core/files/doc_kind.dart';

/// Motores web empaquetados para renderizar documentos Office en el visor.
enum OfficeEngine {
  docx,
  xlsx,
  pptx;

  /// URL de entrada servida localmente mediante `WebViewAssetLoader`.
  String get entryUrl =>
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/$name/index.html';

  /// Devuelve el motor correspondiente a [kind], o `null` si no usa motor web.
  static OfficeEngine? forKind(DocKind kind) => switch (kind) {
        DocKind.word => docx,
        DocKind.excel => xlsx,
        DocKind.powerpoint => pptx,
        DocKind.pdf => null,
      };
}
