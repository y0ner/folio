import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../files/doc_kind.dart';

/// Estado de la aplicación predeterminada para un tipo de documento.
enum DefaultState { folio, other, none }

/// Estado resuelto para un [DocKind] al consultar qué app lo abre por defecto.
@immutable
class DefaultAppStatus {
  const DefaultAppStatus({
    required this.kind,
    required this.state,
    this.appName,
    this.packageName,
  });

  final DocKind kind;
  final DefaultState state;
  final String? appName;
  final String? packageName;

  /// Crea un [DefaultAppStatus] desde el mapa recibido del canal nativo.
  static DefaultAppStatus? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final rawKind = map['kind'];
    final rawState = map['state'];
    if (rawKind is! String || rawState is! String) return null;

    final kind = DocKind.values.asNameMap()[rawKind];
    final state = DefaultState.values.asNameMap()[rawState];
    if (kind == null || state == null) return null;

    final rawAppName = map['appName'];
    final appName =
        rawAppName is String && rawAppName.isNotEmpty ? rawAppName : null;
    final rawPackage = map['package'];
    final packageName =
        rawPackage is String && rawPackage.isNotEmpty ? rawPackage : null;

    return DefaultAppStatus(
      kind: kind,
      state: state,
      appName: appName,
      packageName: packageName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DefaultAppStatus &&
      other.kind == kind &&
      other.state == state &&
      other.appName == appName &&
      other.packageName == packageName;

  @override
  int get hashCode => Object.hash(kind, state, appName, packageName);
}

/// Puente con Android para consultar y cambiar la app predeterminada por tipo.
class DefaultApps {
  DefaultApps({MethodChannel? channel, bool? isAndroid})
      : _channel = channel ?? _defaultChannel,
        _isAndroid =
            isAndroid ?? (channel != null || (!kIsWeb && Platform.isAndroid));

  static const MethodChannel _defaultChannel = MethodChannel('folio/defaults');

  final MethodChannel _channel;
  final bool _isAndroid;

  /// Consulta la app predeterminada actual para cada tipo de documento.
  ///
  /// Fuera de Android devuelve una lista vacía.
  Future<List<DefaultAppStatus>> status() async {
    if (!_isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('status');
      if (raw == null) return const [];
      final out = <DefaultAppStatus>[];
      for (final item in raw) {
        final parsed = item is Map<Object?, Object?>
            ? DefaultAppStatus.fromMap(item)
            : null;
        if (parsed != null) {
          out.add(parsed);
        } else {
          debugPrint('DefaultApps.status: entrada inválida ($item)');
        }
      }
      return out;
    } on MissingPluginException catch (e) {
      debugPrint('DefaultApps.status: canal no disponible ($e)');
      return const [];
    } on PlatformException catch (e) {
      debugPrint('DefaultApps.status: error nativo ($e)');
      rethrow;
    }
  }

  /// Abre el selector del sistema sobre un archivo de muestra para [kind].
  Future<void> choose(DocKind kind) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('choose', {'kind': kind.name});
    } on MissingPluginException catch (e) {
      debugPrint('DefaultApps.choose: canal no disponible ($e)');
    } on PlatformException catch (e) {
      debugPrint('DefaultApps.choose: error nativo ($e)');
      rethrow;
    }
  }

  /// Abre los ajustes de aplicación de [package] para borrar valores predeterminados.
  Future<void> openAppSettings(String package) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'openAppSettings',
        {'package': package},
      );
    } on MissingPluginException catch (e) {
      debugPrint('DefaultApps.openAppSettings: canal no disponible ($e)');
    } on PlatformException catch (e) {
      debugPrint('DefaultApps.openAppSettings: error nativo ($e)');
      rethrow;
    }
  }
}
