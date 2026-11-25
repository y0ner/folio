import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/viewer/pdf/pdf_search.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  group('buildPdfSearchPattern', () {
    test('ignora mayúsculas y tildes en ambas direcciones', () {
      final pattern = buildPdfSearchPattern('tecnico');
      const text = 'Informe Técnico y TÉCNICO sobre tecnica\u0301';
      final matches = pattern.allMatches(text).map((m) => m.group(0)).toList();

      expect(matches, ['Técnico', 'TÉCNICO']);
    });

    test('encuentra texto sin tildes al buscar con tildes o diéresis', () {
      final pattern = buildPdfSearchPattern('pingüino español');
      const text = 'Un PINGUINO ESPANOL y un pingüino español';
      final matches = pattern.allMatches(text).map((m) => m.group(0)).toList();

      expect(matches, ['PINGUINO ESPANOL', 'pingüino español']);
    });

    test('coincide con marcas diacríticas combinadas NFD', () {
      final pattern = buildPdfSearchPattern('cancion');
      const text = 'Una cancio\u0301n y otra cancio\u0301n';
      final matches = pattern.allMatches(text).map((m) => m.group(0)).toList();

      expect(matches, ['cancio\u0301n', 'cancio\u0301n']);
    });

    test('escapa caracteres especiales de expresiones regulares', () {
      final pattern = buildPdfSearchPattern('v1.0 (c++) [2]');
      const text = 'Versión v1.0 (C++) [2] y v1X0 (c++) [2]';
      final matches = pattern.allMatches(text).map((m) => m.group(0)).toList();

      expect(matches, ['v1.0 (C++) [2]']);
    });

    test('devuelve cadena vacía si la consulta está vacía', () {
      expect(buildPdfSearchPattern(''), '');
    });
  });

  group('PdfViewerSearch', () {
    test('estado inicial y clear seguro sin resultados', () {
      final pdfController = PdfViewerController();
      final search = PdfViewerSearch(pdfController);
      addTearDown(search.dispose);

      expect(search.query, '');
      expect(search.isSearching, isFalse);
      expect(search.matchCount, 0);
      expect(search.currentIndex, -1);

      search.next();
      search.previous();
      search.clear();

      expect(search.query, '');
      expect(search.matchCount, 0);
      expect(search.currentIndex, -1);
    });

    test('search("") equivale a clear()', () {
      final pdfController = PdfViewerController();
      final search = PdfViewerSearch(pdfController);
      addTearDown(search.dispose);

      search.search('hola');
      expect(search.query, 'hola');

      search.search('');
      expect(search.query, '');
      expect(search.matchCount, 0);
      expect(search.currentIndex, -1);
    });
  });
}
