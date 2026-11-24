import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/app_scope.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/document_ref.dart';
import 'package:folio/core/files/file_intake.dart';
import 'package:folio/core/files/recent_store.dart';
import 'package:folio/core/settings/settings_store.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<SharedPreferencesWithCache> _createPrefs() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}

Widget _buildApp({
  required RecentStore recents,
  required SettingsStore settings,
}) {
  return AppScope(
    recents: recents,
    settings: settings,
    intake: FileIntake(),
    child: MaterialApp(
      theme: FolioTheme.light(),
      home: const HomeScreen(),
    ),
  );
}

void main() {
  testWidgets('sin recientes muestra el estado vacío inicial', (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);

    await tester.pumpWidget(_buildApp(recents: recents, settings: settings));

    expect(find.text('Abre tu primer documento'), findsOneWidget);
    expect(find.text('Abrir archivo'), findsOneWidget);
  });

  testWidgets('muestra recientes y el filtro Word deja solo el docx',
      (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);
    final now = DateTime.now();

    await recents.add(DocumentRef(
      path: '/docs/contrato.pdf',
      name: 'contrato.pdf',
      kind: DocKind.pdf,
      sizeBytes: 2048,
      openedAt: now,
    ));
    await recents.add(DocumentRef(
      path: '/docs/memoria.docx',
      name: 'memoria.docx',
      kind: DocKind.word,
      sizeBytes: 4096,
      openedAt: now,
    ));

    await tester.pumpWidget(_buildApp(recents: recents, settings: settings));

    expect(find.text('contrato.pdf'), findsOneWidget);
    expect(find.text('memoria.docx'), findsOneWidget);

    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    expect(find.text('memoria.docx'), findsOneWidget);
    expect(find.text('contrato.pdf'), findsNothing);
  });
}
