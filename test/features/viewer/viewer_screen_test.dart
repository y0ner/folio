import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/viewer/viewer_controller.dart';
import 'package:folio/features/viewer/viewer_screen.dart';
import 'package:folio/features/viewer/widgets/document_info_sheet.dart';
import 'package:folio/features/viewer/widgets/page_indicator.dart';

void main() {
  late Directory tempDir;
  late File tempFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('folio_viewer_test_');
    tempFile = File('${tempDir.path}/documento.pdf')
      ..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  DocumentRef makeDoc({
    String? path,
    DocKind kind = DocKind.pdf,
    String name = 'documento.pdf',
    int sizeBytes = 2048,
  }) =>
      DocumentRef(
        path: path ?? tempFile.path,
        name: name,
        kind: kind,
        sizeBytes: sizeBytes,
        openedAt: DateTime(2026, 5, 14, 9, 30),
      );

  Widget wrap(Widget child) => MaterialApp(
        theme: FolioTheme.light(),
        home: child,
      );

  testWidgets('archivo inexistente muestra "El archivo ya no está"',
      (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);
    final missingDoc = makeDoc(path: '${tempDir.path}/no_existe.pdf');

    await tester.pumpWidget(
      wrap(ViewerScreen(document: missingDoc, controller: controller)),
    );

    expect(controller.status, ViewerStatus.failed);
    expect(controller.failure?.kind, ViewerFailureKind.missing);
    expect(find.text('El archivo ya no está'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
  });

  testWidgets('markReady con páginas muestra el indicador de página',
      (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ViewerScreen(document: makeDoc(), controller: controller)),
    );

    controller.markReady(pageCount: 12);
    controller.setPage(3);
    await tester.pump();

    expect(find.text('3 / 12'), findsOneWidget);
  });

  testWidgets('markReady con secciones muestra los chips y permite seleccionar',
      (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        ViewerScreen(
          // La barra de secciones depende solo del controlador; se usa un PDF
          // porque el cuerpo de Excel necesita la plataforma del WebView.
          document: makeDoc(name: 'ventas.pdf'),
          controller: controller,
        ),
      ),
    );

    controller.markReady(sections: const ['Hoja1', 'Hoja2']);
    await tester.pump();

    expect(find.text('Hoja1'), findsOneWidget);
    expect(find.text('Hoja2'), findsOneWidget);
    expect(find.byType(PageIndicator), findsNothing);

    await tester.tap(find.text('Hoja2'));
    await tester.pump();

    expect(controller.currentSection, 1);
  });

  testWidgets('fail(encrypted) muestra "Documento protegido"', (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ViewerScreen(document: makeDoc(), controller: controller)),
    );

    controller.fail(const ViewerFailure(ViewerFailureKind.encrypted));
    await tester.pump();

    expect(find.text('Documento protegido'), findsOneWidget);
    expect(find.text('Compartir con otra app'), findsOneWidget);
  });

  testWidgets('diálogo ir a la página valida el rango y navega',
      (tester) async {
    final controller = ViewerController();
    int? requestedPage;
    controller.attach(onGoToPage: (page) => requestedPage = page);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ViewerScreen(document: makeDoc(), controller: controller)),
    );

    controller.markReady(pageCount: 12);
    controller.setPage(3);
    await tester.pump();

    await tester.tap(find.text('3 / 12'));
    await tester.pumpAndSettle();

    expect(find.text('1 – 12'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '99');
    await tester.tap(find.text('Ir'));
    await tester.pump();

    expect(find.text('Escribe un número entre 1 y 12'), findsOneWidget);
    expect(requestedPage, isNull);

    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Ir'));
    await tester.pumpAndSettle();

    expect(requestedPage, 7);
  });

  testWidgets('hoja de información muestra metadatos formateados',
      (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ViewerScreen(document: makeDoc(), controller: controller)),
    );

    controller.markReady(pageCount: 12);
    await tester.pump();

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Información del archivo'));
    await tester.pumpAndSettle();

    expect(find.text('Información del archivo'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DocumentInfoSheet),
        matching: find.text('PDF'),
      ),
      findsOneWidget,
    );
    expect(find.text('2,0 KB'), findsOneWidget);
    expect(find.text('14/05/2026 09:30'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('el indicador de carga aparece solo si tarda más de 300 ms',
      (tester) async {
    final controller = ViewerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ViewerScreen(document: makeDoc(), controller: controller)),
    );

    expect(find.text('Abriendo documento…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Abriendo documento…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Abriendo documento…'), findsOneWidget);

    controller.markReady(pageCount: 1);
    await tester.pump();
    expect(find.text('Abriendo documento…'), findsNothing);
  });
}
