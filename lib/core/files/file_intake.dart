import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'doc_kind.dart';
import 'document_ref.dart';
import 'incoming_files.dart';

/// Resultado de intentar obtener un documento.
sealed class IntakeResult {
  const IntakeResult();
}

class IntakeOpened extends IntakeResult {
  const IntakeOpened(this.document);
  final DocumentRef document;
}

/// El usuario canceló el selector.
class IntakeCancelled extends IntakeResult {
  const IntakeCancelled();
}

/// El archivo no es de un tipo admitido.
class IntakeUnsupported extends IntakeResult {
  const IntakeUnsupported(this.name);
  final String name;
}

/// Obtiene documentos del sistema y los copia al almacenamiento de la app.
class FileIntake {
  FileIntake({
    Future<Directory> Function()? baseDir,
    Future<IncomingFile?> Function()? nativePick,
  })  : _baseDir = baseDir ?? getApplicationSupportDirectory,
        _nativePick = nativePick ?? IncomingFiles.pick;

  final Future<Directory> Function() _baseDir;
  final Future<IncomingFile?> Function() _nativePick;

  /// Carpeta donde viven las copias locales de los documentos.
  Future<Directory> documentsDir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'documents'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Abre el selector de archivos del sistema.
  Future<IntakeResult> pick() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _pickNative();
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: DocKind.allExtensions.toList(),
    );
    if (file == null || file.path == null) return const IntakeCancelled();
    final rawUri = file.uri.toString();
    return importFile(
      File(file.path!),
      name: file.name,
      sourceUri: rawUri.isEmpty ? null : rawUri,
    );
  }

  Future<IntakeResult> _pickNative() async {
    final incoming = await _nativePick();
    if (incoming == null) return const IntakeCancelled();
    final source = File(incoming.path);
    try {
      return await importFile(
        source,
        name: incoming.name,
        sourceUri: incoming.uri,
      );
    } finally {
      await _deleteTempFile(source);
    }
  }

  Future<void> _deleteTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('No se pudo borrar copia temporal ${file.path}: $e');
    }
  }

  /// Copia [source] a la carpeta de documentos y devuelve su referencia.
  Future<IntakeResult> importFile(
    File source, {
    required String name,
    String? sourceUri,
  }) async {
    final kind = DocKind.fromName(name);
    if (kind == null) return IntakeUnsupported(name);
    final dir = await documentsDir();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = File(p.join(dir.path, '${stamp}_$name'));
    await source.copy(target.path);
    return IntakeOpened(DocumentRef(
      path: target.path,
      name: name,
      kind: kind,
      sizeBytes: await target.length(),
      openedAt: DateTime.now(),
      source: sourceUri != null && sourceUri.isNotEmpty ? sourceUri : null,
    ));
  }

  /// Borra la copia local de [ref] si está dentro de la carpeta de la app.
  Future<void> deleteLocalCopy(DocumentRef ref) async {
    final dir = await documentsDir();
    if (!p.isWithin(dir.path, ref.path)) return;
    final f = File(ref.path);
    if (f.existsSync()) await f.delete();
  }
}
