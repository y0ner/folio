import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/app_scope.dart';
import 'package:folio/core/defaults/default_apps.dart';
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

Future<SharedPreferencesWithCache> _createPrefs({bool reset = true}) {
  if (reset) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  }
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}

Widget _buildApp({
  Key? key,
  required RecentStore recents,
  required SettingsStore settings,
  DefaultApps? defaultApps,
}) {
  return AppScope(
    key: key,
    recents: recents,
    settings: settings,
    intake: FileIntake(),
    child: MaterialApp(
      theme: FolioTheme.light(),
      home: HomeScreen(defaultApps: defaultApps),
    ),
  );
}

void main() {
  const channel = MethodChannel('folio/defaults');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

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

  testWidgets(
      'muestra tarjeta de app predeterminada con algún tipo none y la oculta al cerrarla',
      (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') {
        return [
          {'kind': 'pdf', 'state': 'none'},
          {'kind': 'word', 'state': 'folio'},
        ];
      }
      return null;
    });

    await tester.pumpWidget(_buildApp(
      recents: recents,
      settings: settings,
      defaultApps: DefaultApps(channel: channel),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Haz de Folio tu visor predeterminado'), findsOneWidget);
    expect(find.text('Elegir'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Haz de Folio tu visor predeterminado'), findsNothing);
    expect(
      await SharedPreferencesAsync().getBool('home.defaultsBannerDismissed'),
      isTrue,
    );

    // Al volver a construir HomeScreen recuerda que se cerró.
    final prefsReloaded = await _createPrefs(reset: false);
    await tester.pumpWidget(_buildApp(
      key: UniqueKey(),
      recents: RecentStore(prefsReloaded),
      settings: SettingsStore(prefsReloaded),
      defaultApps: DefaultApps(channel: channel),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Haz de Folio tu visor predeterminado'), findsNothing);
  });

  testWidgets(
      'no muestra la tarjeta si status está vacío o todos los tipos son Folio',
      (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);

    var items = <Map<String, String>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => items);

    await tester.pumpWidget(_buildApp(
      recents: recents,
      settings: settings,
      defaultApps: DefaultApps(channel: channel),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Haz de Folio tu visor predeterminado'), findsNothing);

    items = [
      {'kind': 'pdf', 'state': 'folio'},
      {'kind': 'word', 'state': 'folio'},
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Haz de Folio tu visor predeterminado'), findsNothing);
  });

  testWidgets('tocar Elegir en la tarjeta navega a Ajustes', (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') {
        return [
          {'kind': 'pdf', 'state': 'none'},
        ];
      }
      return null;
    });

    await tester.pumpWidget(_buildApp(
      recents: recents,
      settings: settings,
      defaultApps: DefaultApps(channel: channel),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('ABRIR DOCUMENTOS'), findsOneWidget);
  });
}
