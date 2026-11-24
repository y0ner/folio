import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/viewer/office/office_document_view.dart';
import 'package:folio/features/viewer/viewer_controller.dart';

void main() {
  testWidgets('falla con unsupported si el tipo no tiene motor web', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final doc = DocumentRef(
      path: '/tmp/documento.pdf',
      name: 'documento.pdf',
      kind: DocKind.pdf,
      sizeBytes: 100,
      openedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FolioTheme.light(),
        home: OfficeDocumentView(
          document: doc,
          controller: controller,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(controller.status, ViewerStatus.failed);
    expect(controller.failure?.kind, ViewerFailureKind.unsupported);

    final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(box.color, FolioColors.light.canvas);
  });

  testWidgets('falla con missing si el archivo no existe en disco', (
    tester,
  ) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    final doc = DocumentRef(
      path: '/tmp/no_existe_folio_test_12345.docx',
      name: 'no_existe_folio_test_12345.docx',
      kind: DocKind.word,
      sizeBytes: 100,
      openedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FolioTheme.dark(),
        home: OfficeDocumentView(
          document: doc,
          controller: controller,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(controller.status, ViewerStatus.failed);
    expect(controller.failure?.kind, ViewerFailureKind.missing);

    final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(box.color, FolioColors.dark.canvas);
  });
}
