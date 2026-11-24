import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/features/home/recent_groups.dart';

DocumentRef _doc(String name, DateTime openedAt) => DocumentRef(
      path: '/docs/$name',
      name: name,
      kind: DocKind.fromName(name)!,
      sizeBytes: 1024,
      openedAt: openedAt,
    );

void main() {
  final now = DateTime(2026, 11, 24, 15, 0);

  group('groupRecents', () {
    test('agrupa en Hoy, Esta semana y Anteriores conservando el orden', () {
      final hoy1 = _doc('a.pdf', DateTime(2026, 11, 24, 14, 0));
      final hoy2 = _doc('b.docx', DateTime(2026, 11, 24, 9, 0));
      final sem1 = _doc('c.xlsx', DateTime(2026, 11, 23, 20, 0));
      final sem2 = _doc('d.pptx', DateTime(2026, 11, 17, 10, 0));
      final ant1 = _doc('e.pdf', DateTime(2026, 11, 16, 18, 0));
      final ant2 = _doc('f.docx', DateTime(2025, 10, 1, 12, 0));

      final groups = groupRecents(
        [hoy1, hoy2, sem1, sem2, ant1, ant2],
        now: now,
      );

      expect(groups.map((g) => g.label), ['Hoy', 'Esta semana', 'Anteriores']);
      expect(groups[0].items, [hoy1, hoy2]);
      expect(groups[1].items, [sem1, sem2]);
      expect(groups[2].items, [ant1, ant2]);
    });

    test('omite grupos vacíos', () {
      final hoy = _doc('a.pdf', DateTime(2026, 11, 24, 12, 0));
      final ant = _doc('b.pdf', DateTime(2026, 10, 1, 12, 0));

      final groups = groupRecents([hoy, ant], now: now);
      expect(groups.map((g) => g.label), ['Hoy', 'Anteriores']);
      expect(groupRecents(const [], now: now), isEmpty);
    });
  });

  group('filterRecents', () {
    final items = [
      _doc('Informe Técnico.pdf', now),
      _doc('Presupuesto.xlsx', now),
      _doc('Resumen Técnico.docx', now),
    ];

    test('filtra por tipo de documento', () {
      final result = filterRecents(items, kind: DocKind.word);
      expect(result.map((e) => e.name), ['Resumen Técnico.docx']);
    });

    test('busca sin distinguir mayúsculas ni tildes', () {
      expect(
        filterRecents(items, query: 'informe').map((e) => e.name),
        ['Informe Técnico.pdf'],
      );
      expect(
        filterRecents(items, query: 'tecnico').map((e) => e.name),
        ['Informe Técnico.pdf', 'Resumen Técnico.docx'],
      );
    });

    test('combina búsqueda y filtro por tipo', () {
      expect(
        filterRecents(items, query: 'tecnico', kind: DocKind.pdf)
            .map((e) => e.name),
        ['Informe Técnico.pdf'],
      );
    });
  });
}
