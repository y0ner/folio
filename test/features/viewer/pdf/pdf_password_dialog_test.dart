import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/viewer/pdf/pdf_password_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      theme: FolioTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('devuelve la contraseña escrita al pulsar Abrir', (tester) async {
    String? result = 'sentinel';

    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await PdfPasswordDialog.show(context);
            },
            child: const Text('Mostrar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();

    expect(find.text('Documento protegido'), findsOneWidget);
    expect(find.text('Contraseña incorrecta'), findsNothing);

    await tester.enterText(find.byType(TextField), 'secreto123');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(result, 'secreto123');
  });

  testWidgets('devuelve null al pulsar Cancelar', (tester) async {
    String? result = 'sentinel';

    await tester.pumpWidget(
      wrapWithApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await PdfPasswordDialog.show(context);
            },
            child: const Text('Mostrar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'algo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('muestra Contraseña incorrecta cuando se le indica',
      (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const PdfPasswordDialog(incorrectPassword: true),
      ),
    );

    expect(find.text('Documento protegido'), findsOneWidget);
    expect(find.text('Contraseña incorrecta'), findsOneWidget);
  });

  testWidgets('alterna la visibilidad de la contraseña', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const PdfPasswordDialog(),
      ),
    );

    TextField field() => tester.widget<TextField>(find.byType(TextField));

    expect(field().obscureText, isTrue);
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.eye));
    await tester.pump();

    expect(field().obscureText, isFalse);
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
  });
}
