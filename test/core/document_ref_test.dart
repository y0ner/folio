import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';

void main() {
  test('ida y vuelta JSON conserva source cuando está presente', () {
    final doc = DocumentRef(
      path: '/app/docs/123_carta.docx',
      name: 'carta.docx',
      kind: DocKind.word,
      sizeBytes: 4096,
      openedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      source:
          'content://com.android.externalstorage.documents/document/primary%3ADownload%2Fcarta.docx',
    );

    final json = doc.toJson();
    expect(json['source'], doc.source);

    final restored = DocumentRef.fromJson(json);
    expect(restored, isNotNull);
    expect(restored!.source, doc.source);
    expect(restored.name, 'carta.docx');
    expect(restored.kind, DocKind.word);
  });

  test('ida y vuelta JSON sin source y lectura de JSON viejo sin clave source',
      () {
    final doc = DocumentRef(
      path: '/app/docs/123_acta.pdf',
      name: 'acta.pdf',
      kind: DocKind.pdf,
      sizeBytes: 1024,
      openedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    final json = doc.toJson();
    expect(json.containsKey('source'), isFalse);

    final restored = DocumentRef.fromJson(json);
    expect(restored, isNotNull);
    expect(restored!.source, isNull);

    final legacy = DocumentRef.fromJson({
      'path': '/app/docs/viejo.pdf',
      'name': 'viejo.pdf',
      'kind': 'pdf',
      'size': 512,
      'openedAt': 1700000000000,
    });
    expect(legacy, isNotNull);
    expect(legacy!.source, isNull);
  });

  test('fromJson ignora source vacío o de tipo inválido', () {
    final emptySource = DocumentRef.fromJson({
      'path': '/app/docs/a.pdf',
      'name': 'a.pdf',
      'kind': 'pdf',
      'size': 10,
      'openedAt': 1700000000000,
      'source': '',
    });
    expect(emptySource?.source, isNull);

    final invalidSource = DocumentRef.fromJson({
      'path': '/app/docs/b.pdf',
      'name': 'b.pdf',
      'kind': 'pdf',
      'size': 10,
      'openedAt': 1700000000000,
      'source': 42,
    });
    expect(invalidSource?.source, isNull);
  });

  test('copyWith conserva y permite actualizar source', () {
    final doc = DocumentRef(
      path: '/app/docs/a.pdf',
      name: 'a.pdf',
      kind: DocKind.pdf,
      sizeBytes: 10,
      openedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      source: 'file:///storage/emulated/0/a.pdf',
    );

    final touched =
        doc.copyWith(openedAt: DateTime.fromMillisecondsSinceEpoch(2000));
    expect(touched.source, doc.source);

    final updated = doc.copyWith(source: 'content://com.whatsapp/item/1');
    expect(updated.source, 'content://com.whatsapp/item/1');
  });
}
