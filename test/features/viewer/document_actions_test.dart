import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/features/viewer/document_actions.dart';

void main() {
  late Directory tempDir;
  late File tempFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('folio_actions_test_');
    tempFile = File('${tempDir.path}/informe.docx')
      ..writeAsBytesSync([10, 20, 30, 40]);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  DocumentRef makeDoc({
    String? path,
    String name = 'informe.docx',
    DocKind kind = DocKind.word,
    int sizeBytes = 4,
  }) =>
      DocumentRef(
        path: path ?? tempFile.path,
        name: name,
        kind: kind,
        sizeBytes: sizeBytes,
        openedAt: DateTime(2026, 5, 14),
      );

  test('mimeTypeForDocument resuelve los tipos MIME por extensión', () {
    expect(
      mimeTypeForDocument(makeDoc(name: 'a.pdf', kind: DocKind.pdf)),
      'application/pdf',
    );
    expect(
      mimeTypeForDocument(makeDoc(name: 'a.docx', kind: DocKind.word)),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(
      mimeTypeForDocument(makeDoc(name: 'a.csv', kind: DocKind.excel)),
      'text/csv',
    );
    expect(
      mimeTypeForDocument(makeDoc(name: 'a.pptx', kind: DocKind.powerpoint)),
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    );
  });

  test('saveDocumentCopy guarda bytes y devuelve saved', () async {
    String? capturedName;
    Uint8List? capturedBytes;
    String? capturedMime;
    String? capturedTitle;

    final result = await saveDocumentCopy(
      makeDoc(),
      saveFile: ({
        required fileName,
        required bytes,
        required mimeType,
        dialogTitle,
      }) async {
        capturedName = fileName;
        capturedBytes = bytes;
        capturedMime = mimeType;
        capturedTitle = dialogTitle;
        return Uri.parse('content://downloads/copy.docx');
      },
    );

    expect(result, SaveCopyResult.saved);
    expect(capturedName, 'informe.docx');
    expect(capturedBytes, Uint8List.fromList([10, 20, 30, 40]));
    expect(
      capturedMime,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(capturedTitle, 'Guardar una copia');
  });

  test('saveDocumentCopy devuelve cancelled si el usuario cancela', () async {
    final result = await saveDocumentCopy(
      makeDoc(),
      saveFile: ({
        required fileName,
        required bytes,
        required mimeType,
        dialogTitle,
      }) async =>
          null,
    );

    expect(result, SaveCopyResult.cancelled);
  });

  test('saveDocumentCopy rechaza archivos mayores de 150 MB sin llamar saveFile',
      () async {
    var called = false;
    final result = await saveDocumentCopy(
      makeDoc(sizeBytes: maxCopySizeBytes + 1),
      saveFile: ({
        required fileName,
        required bytes,
        required mimeType,
        dialogTitle,
      }) async {
        called = true;
        return Uri.parse('content://downloads/copy.docx');
      },
    );

    expect(result, SaveCopyResult.tooLarge);
    expect(called, isFalse);
  });

  test('saveDocumentCopy devuelve failed si el archivo falta o saveFile falla',
      () async {
    final missing = await saveDocumentCopy(
      makeDoc(path: '${tempDir.path}/no_existe.docx'),
    );
    expect(missing, SaveCopyResult.failed);

    final errored = await saveDocumentCopy(
      makeDoc(),
      saveFile: ({
        required fileName,
        required bytes,
        required mimeType,
        dialogTitle,
      }) async {
        throw StateError('Fallo simulado');
      },
    );
    expect(errored, SaveCopyResult.failed);
  });
}
