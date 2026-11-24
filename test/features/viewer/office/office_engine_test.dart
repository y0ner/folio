import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/features/viewer/office/office_engine.dart';

void main() {
  test('forKind asigna el motor correcto para cada tipo Office y null para PDF', () {
    expect(OfficeEngine.forKind(DocKind.word), OfficeEngine.docx);
    expect(OfficeEngine.forKind(DocKind.excel), OfficeEngine.xlsx);
    expect(OfficeEngine.forKind(DocKind.powerpoint), OfficeEngine.pptx);
    expect(OfficeEngine.forKind(DocKind.pdf), isNull);
  });

  test('entryUrl apunta a los assets empaquetados locales por motor', () {
    expect(
      OfficeEngine.docx.entryUrl,
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/docx/index.html',
    );
    expect(
      OfficeEngine.xlsx.entryUrl,
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/xlsx/index.html',
    );
    expect(
      OfficeEngine.pptx.entryUrl,
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/pptx/index.html',
    );
  });
}
