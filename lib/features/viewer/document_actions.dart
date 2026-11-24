import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/files/doc_kind.dart';
import '../../core/files/document_ref.dart';

/// Tamaño máximo (150 MB) permitido para copiar en memoria con [FilePicker.saveFile].
const int maxCopySizeBytes = 150 * 1024 * 1024;

/// Resultado de intentar guardar una copia del documento en otra carpeta.
enum SaveCopyResult {
  saved,
  cancelled,
  tooLarge,
  failed,
}

/// Firma inyectable de guardado para facilitar pruebas unitarias.
typedef SaveFileFn = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? dialogTitle,
});

const Map<String, String> _mimeByExtension = {
  'pdf': 'application/pdf',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'docm': 'application/vnd.ms-word.document.macroEnabled.12',
  'dotx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.template',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'xlsm': 'application/vnd.ms-excel.sheet.macroEnabled.12',
  'xls': 'application/vnd.ms-excel',
  'csv': 'text/csv',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'ppsx':
      'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
  'pptm': 'application/vnd.ms-powerpoint.presentation.macroEnabled.12',
};

/// Devuelve el tipo MIME correspondiente a [doc] según su extensión o [DocKind].
String mimeTypeForDocument(DocumentRef doc) {
  final ext = p.extension(doc.name).replaceFirst('.', '').toLowerCase();
  final byExt = _mimeByExtension[ext];
  if (byExt != null) return byExt;

  return switch (doc.kind) {
    DocKind.pdf => 'application/pdf',
    DocKind.word =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    DocKind.excel =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    DocKind.powerpoint =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };
}

/// Abre el selector del sistema para guardar una copia de [doc].
Future<SaveCopyResult> saveDocumentCopy(
  DocumentRef doc, {
  @visibleForTesting SaveFileFn? saveFile,
}) async {
  final file = File(doc.path);
  try {
    if (!await file.exists()) {
      debugPrint('saveDocumentCopy: archivo no existe (${doc.path})');
      return SaveCopyResult.failed;
    }
    if (doc.sizeBytes > maxCopySizeBytes ||
        await file.length() > maxCopySizeBytes) {
      return SaveCopyResult.tooLarge;
    }
    final bytes = await file.readAsBytes();
    final saver = saveFile ?? _defaultSaveFile;
    final savedUri = await saver(
      fileName: doc.name,
      bytes: bytes,
      mimeType: mimeTypeForDocument(doc),
      dialogTitle: 'Guardar una copia',
    );
    return savedUri != null ? SaveCopyResult.saved : SaveCopyResult.cancelled;
  } catch (e, st) {
    debugPrint('saveDocumentCopy: error al guardar ${doc.name}: $e\n$st');
    return SaveCopyResult.failed;
  }
}

Future<Uri?> _defaultSaveFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? dialogTitle,
}) {
  return FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );
}
