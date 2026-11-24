import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/file_intake.dart';

void main() {
  late Directory tempDir;
  late File sourceFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('folio_intake_test_');
    sourceFile = File('${tempDir.path}/borrador.docx')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('importFile guarda sourceUri en el DocumentRef generado', () async {
    final intake = FileIntake(baseDir: () async => tempDir);
    const uri =
        'content://com.android.externalstorage.documents/document/primary%3ADownload%2Fborrador.docx';

    final result = await intake.importFile(
      sourceFile,
      name: 'borrador.docx',
      sourceUri: uri,
    );

    expect(result, isA<IntakeOpened>());
    final doc = (result as IntakeOpened).document;
    expect(doc.name, 'borrador.docx');
    expect(doc.source, uri);
    expect(File(doc.path).existsSync(), isTrue);
  });

  test('importFile omite sourceUri vacío', () async {
    final intake = FileIntake(baseDir: () async => tempDir);

    final result = await intake.importFile(
      sourceFile,
      name: 'borrador.docx',
      sourceUri: '',
    );

    expect(result, isA<IntakeOpened>());
    expect((result as IntakeOpened).document.source, isNull);
  });
}
