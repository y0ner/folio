import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/file_intake.dart';
import 'package:folio/core/files/incoming_files.dart';

void main() {
  late Directory tempDir;
  late File sourceFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('folio_intake_test_');
    sourceFile = File('${tempDir.path}/borrador.docx')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
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

  test('pick en Android usa nativePick, guarda source y borra copia temporal', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final incomingCopy = File('${tempDir.path}/incoming_carta.docx')
      ..writeAsBytesSync([9, 8, 7]);
    const realUri = 'file:///storage/emulated/0/Download/carta%20solicitud.docx';

    final intake = FileIntake(
      baseDir: () async => tempDir,
      nativePick: () async => IncomingFile(
        path: incomingCopy.path,
        name: 'carta solicitud.docx',
        uri: realUri,
      ),
    );

    final result = await intake.pick();

    expect(result, isA<IntakeOpened>());
    final doc = (result as IntakeOpened).document;
    expect(doc.name, 'carta solicitud.docx');
    expect(doc.source, realUri);
    expect(File(doc.path).existsSync(), isTrue);
    expect(incomingCopy.existsSync(), isFalse);
  });

  test('pick en Android devuelve IntakeCancelled si nativePick devuelve null', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final intake = FileIntake(
      baseDir: () async => tempDir,
      nativePick: () async => null,
    );

    expect(await intake.pick(), isA<IntakeCancelled>());
  });

  test('pick en Android borra copia temporal aunque el tipo no sea admitido', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final incomingCopy = File('${tempDir.path}/nota.txt')
      ..writeAsBytesSync([1, 2]);
    final intake = FileIntake(
      baseDir: () async => tempDir,
      nativePick: () async => IncomingFile(
        path: incomingCopy.path,
        name: 'nota.txt',
        uri: 'file:///storage/emulated/0/Download/nota.txt',
      ),
    );

    final result = await intake.pick();

    expect(result, isA<IntakeUnsupported>());
    expect(incomingCopy.existsSync(), isFalse);
  });
}
