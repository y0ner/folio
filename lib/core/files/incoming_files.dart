import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'doc_kind.dart';

/// Archivo recibido desde otra aplicación de Android.
@immutable
class IncomingFile {
  const IncomingFile({required this.path, required this.name, this.uri});

  final String path;
  final String name;
  final String? uri;

  /// Crea un [IncomingFile] desde [map], o `null` si faltan `path` o `name`.
  static IncomingFile? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final path = map['path'];
    final name = map['name'];
    if (path is! String || path.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    final rawUri = map['uri'];
    final uri = rawUri is String && rawUri.isNotEmpty ? rawUri : null;
    return IncomingFile(path: path, name: name, uri: uri);
  }

  @override
  bool operator ==(Object other) =>
      other is IncomingFile &&
      other.path == path &&
      other.name == name &&
      other.uri == uri;

  @override
  int get hashCode => Object.hash(path, name, uri);
}

/// Puente con Android para recibir archivos de "Abrir con" y "Compartir".
class IncomingFiles {
  IncomingFiles({MethodChannel? channel})
      : _channel = channel ?? _defaultChannel {
    _channel.setMethodCallHandler(_handleCall);
  }

  static const MethodChannel _defaultChannel = MethodChannel('folio/incoming');

  final MethodChannel _channel;
  final StreamController<IncomingFile> _filesController =
      StreamController<IncomingFile>.broadcast();
  final StreamController<DocKind> _defaultChosenController =
      StreamController<DocKind>.broadcast();
  final StreamController<String> _errorsController =
      StreamController<String>.broadcast();

  /// Flujo de archivos recibidos mientras la app está abierta.
  Stream<IncomingFile> get files => _filesController.stream;

  /// Flujo de tipos confirmados al elegir Folio como app predeterminada.
  Stream<DocKind> get defaultChosen => _defaultChosenController.stream;

  /// Flujo de mensajes de error al recibir archivos desde Android.
  Stream<String> get errors => _errorsController.stream;

  /// Abre el selector nativo de documentos en Android sin registrar handler
  /// en el canal (para no pisar el listener de archivos entrantes).
  static Future<IncomingFile?> pick({MethodChannel? channel}) async {
    final target = channel ?? _defaultChannel;
    try {
      final raw = await target.invokeMethod<Object?>('pick');
      if (raw == null) return null;
      if (raw is Map<Object?, Object?>) {
        final file = IncomingFile.fromMap(raw);
        if (file == null) {
          debugPrint('IncomingFiles.pick: datos incompletos ($raw)');
          throw const FormatException('Datos incompletos del selector');
        }
        return file;
      }
      debugPrint('IncomingFiles.pick: respuesta inesperada ($raw)');
      throw const FormatException('Respuesta inesperada del selector');
    } on MissingPluginException catch (e) {
      debugPrint('IncomingFiles.pick: canal no disponible ($e)');
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'busy') {
        debugPrint('IncomingFiles.pick: selector ocupado (${e.message})');
        return null;
      }
      debugPrint('IncomingFiles.pick: error nativo ($e)');
      rethrow;
    }
  }

  /// Devuelve el archivo del Intent inicial (solo la primera vez) o `null`.
  Future<IncomingFile?> initial() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getInitial');
      if (raw == null) return null;
      if (raw is Map<Object?, Object?>) {
        if (raw.containsKey('defaultChosen')) {
          final kind = _parseDocKind(raw['defaultChosen']);
          if (kind != null) {
            if (!_defaultChosenController.isClosed) {
              _defaultChosenController.add(kind);
            }
          } else {
            debugPrint('IncomingFiles.initial: defaultChosen inválido ($raw)');
          }
          return null;
        }
        final file = IncomingFile.fromMap(raw);
        if (file == null) {
          debugPrint('IncomingFiles.initial: datos incompletos ($raw)');
          _emitError('No se pudo recibir el archivo');
        }
        return file;
      }
      debugPrint('IncomingFiles.initial: respuesta inesperada ($raw)');
      _emitError('No se pudo recibir el archivo');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('IncomingFiles.initial: canal no disponible ($e)');
      return null;
    } on PlatformException catch (e) {
      debugPrint('IncomingFiles.initial: error nativo ($e)');
      _emitError(e.message ?? 'No se pudo recibir el archivo');
      return null;
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'onFile':
        final args = call.arguments;
        final file =
            args is Map<Object?, Object?> ? IncomingFile.fromMap(args) : null;
        if (file != null) {
          if (!_filesController.isClosed) _filesController.add(file);
        } else {
          debugPrint('IncomingFiles.onFile: datos incompletos ($args)');
          _emitError('No se pudo recibir el archivo');
        }
      case 'onDefaultChosen':
        final args = call.arguments;
        final kind =
            args is Map<Object?, Object?> ? _parseDocKind(args['kind']) : null;
        if (kind != null) {
          if (!_defaultChosenController.isClosed) {
            _defaultChosenController.add(kind);
          }
        } else {
          debugPrint('IncomingFiles.onDefaultChosen: datos inválidos ($args)');
        }
      case 'onError':
        final args = call.arguments;
        final message = switch (args) {
          Map() => args['message']?.toString(),
          String() => args,
          _ => null,
        };
        debugPrint('IncomingFiles.onError: $message');
        _emitError(
          (message != null && message.isNotEmpty)
              ? message
              : 'No se pudo recibir el archivo',
        );
    }
  }

  DocKind? _parseDocKind(Object? raw) {
    if (raw is! String) return null;
    return DocKind.values.asNameMap()[raw];
  }

  void _emitError(String message) {
    if (!_errorsController.isClosed) {
      _errorsController.add(message);
    }
  }

  /// Libera los recursos del canal y cierra los flujos.
  void dispose() {
    _channel.setMethodCallHandler(null);
    _filesController.close();
    _defaultChosenController.close();
    _errorsController.close();
  }
}
