import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../viewer_controller.dart';

/// Mensajes emitidos por los motores JS hacia el visor en Dart.
@immutable
sealed class EngineMessage {
  const EngineMessage();

  /// Interpreta un mensaje crudo (`Map` o `String` JSON) enviado desde JS.
  ///
  /// Devuelve `null` si el formato es inválido o faltan campos obligatorios.
  static EngineMessage? parse(Object? raw) {
    final map = _asMap(raw);
    if (map == null) return null;

    final type = map['type'];
    if (type is! String) return null;

    return switch (type) {
      'ready' => _parseReady(map),
      'page' => _parsePage(map),
      'tap' => const EngineTap(),
      'error' => _parseError(map),
      _ => null,
    };
  }

  static Map<Object?, Object?>? _asMap(Object? raw) {
    if (raw is Map<Object?, Object?>) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<Object?, Object?>) return decoded;
      } on FormatException catch (e) {
        debugPrint('EngineMessage: JSON inválido ($e)');
      }
    }
    return null;
  }

  static EngineReady? _parseReady(Map<Object?, Object?> map) {
    final pageCount = map['pageCount'];
    if (pageCount is! int || pageCount < 0) return null;

    final rawSections = map['sections'];
    if (rawSections == null) {
      return EngineReady(pageCount);
    }
    if (rawSections is! List) return null;

    final sections = <String>[];
    for (final item in rawSections) {
      if (item is! String) return null;
      sections.add(item);
    }
    return EngineReady(pageCount, List.unmodifiable(sections));
  }

  static EnginePage? _parsePage(Map<Object?, Object?> map) {
    final page = map['page'];
    if (page is! int || page < 1) return null;
    return EnginePage(page);
  }

  static EngineError? _parseError(Map<Object?, Object?> map) {
    final rawKind = map['kind'];
    if (rawKind is! String) return null;

    final kind = switch (rawKind) {
      'encrypted' => ViewerFailureKind.encrypted,
      'corrupt' => ViewerFailureKind.corrupt,
      'unsupported' => ViewerFailureKind.unsupported,
      'engine' => ViewerFailureKind.engine,
      _ => ViewerFailureKind.engine,
    };

    final rawDetail = map['detail'];
    final detail = rawDetail is String ? rawDetail : rawDetail?.toString();
    return EngineError(kind, detail);
  }
}

/// El documento terminó de renderizarse y está listo para leerse.
final class EngineReady extends EngineMessage {
  const EngineReady(this.pageCount, [this.sections = const []]);

  final int pageCount;
  final List<String> sections;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineReady &&
          other.pageCount == pageCount &&
          listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(pageCount, Object.hashAll(sections));

  @override
  String toString() =>
      'EngineReady(pageCount: $pageCount, sections: $sections)';
}

/// Cambio de página visible durante el desplazamiento.
final class EnginePage extends EngineMessage {
  const EnginePage(this.page);

  final int page;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EnginePage && other.page == page;

  @override
  int get hashCode => page.hashCode;

  @override
  String toString() => 'EnginePage(page: $page)';
}

/// Toque simple sobre el contenido (alterna las barras del visor).
final class EngineTap extends EngineMessage {
  const EngineTap();

  @override
  bool operator ==(Object other) => identical(this, other) || other is EngineTap;

  @override
  int get hashCode => (EngineTap).hashCode;

  @override
  String toString() => 'EngineTap()';
}

/// Fallo reportado por el motor al cargar o renderizar el documento.
final class EngineError extends EngineMessage {
  const EngineError(this.kind, [this.detail]);

  final ViewerFailureKind kind;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineError && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => 'EngineError(kind: $kind, detail: $detail)';
}
