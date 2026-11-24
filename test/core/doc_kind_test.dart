import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';

void main() {
  test('deduce el tipo por extensión sin importar mayúsculas', () {
    expect(DocKind.fromName('Informe.PDF'), DocKind.pdf);
    expect(DocKind.fromName('/a/b/tesis final.docx'), DocKind.word);
    expect(DocKind.fromName('notas.xlsx'), DocKind.excel);
    expect(DocKind.fromName('datos.csv'), DocKind.excel);
    expect(DocKind.fromName('clase.pptx'), DocKind.powerpoint);
  });

  test('rechaza extensiones no admitidas', () {
    expect(DocKind.fromName('foto.jpg'), isNull);
    expect(DocKind.fromName('sin_extension'), isNull);
    expect(DocKind.fromName('viejo.doc'), isNull);
  });

  test('deduce el tipo por MIME', () {
    expect(DocKind.fromMime('application/pdf'), DocKind.pdf);
    expect(
      DocKind.fromMime(
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
      DocKind.word,
    );
    expect(DocKind.fromMime('application/vnd.ms-excel'), DocKind.excel);
    expect(
      DocKind.fromMime(
          'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
      DocKind.powerpoint,
    );
    expect(DocKind.fromMime('image/png'), isNull);
    expect(DocKind.fromMime(null), isNull);
  });
}
