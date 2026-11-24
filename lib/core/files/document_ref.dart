import 'package:flutter/foundation.dart';

import 'doc_kind.dart';

/// Un documento que Folio puede abrir.
///
/// [path] apunta siempre a una copia local dentro del almacenamiento de la
/// app (los `content://` de Android se copian al recibirlos), así el
/// documento sigue abriéndose desde "Recientes" aunque el origen cambie.
@immutable
class DocumentRef {
  const DocumentRef({
    required this.path,
    required this.name,
    required this.kind,
    required this.sizeBytes,
    required this.openedAt,
    this.source,
  });

  final String path;

  /// Nombre visible, con extensión ("Informe final.docx").
  final String name;
  final DocKind kind;
  final int sizeBytes;

  /// Última vez que se abrió.
  final DateTime openedAt;

  /// URI original del documento (`content://…` o `file://…`), si se conoce.
  final String? source;

  DocumentRef copyWith({DateTime? openedAt, String? source}) => DocumentRef(
        path: path,
        name: name,
        kind: kind,
        sizeBytes: sizeBytes,
        openedAt: openedAt ?? this.openedAt,
        source: source ?? this.source,
      );

  Map<String, Object> toJson() => {
        'path': path,
        'name': name,
        'kind': kind.name,
        'size': sizeBytes,
        'openedAt': openedAt.millisecondsSinceEpoch,
        'source': ?source,
      };

  /// Devuelve `null` si el JSON está incompleto o el tipo ya no existe.
  static DocumentRef? fromJson(Map<String, dynamic> json) {
    final kind = DocKind.values.asNameMap()[json['kind']];
    final path = json['path'];
    final name = json['name'];
    final size = json['size'];
    final openedAt = json['openedAt'];
    if (kind == null ||
        path is! String ||
        name is! String ||
        size is! int ||
        openedAt is! int) {
      return null;
    }
    final rawSource = json['source'];
    final source =
        rawSource is String && rawSource.isNotEmpty ? rawSource : null;
    return DocumentRef(
      path: path,
      name: name,
      kind: kind,
      sizeBytes: size,
      openedAt: DateTime.fromMillisecondsSinceEpoch(openedAt),
      source: source,
    );
  }

  @override
  bool operator ==(Object other) => other is DocumentRef && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
