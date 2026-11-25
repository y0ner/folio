import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/app_scope.dart';
import 'package:folio/core/defaults/default_apps.dart';
import 'package:folio/core/files/file_intake.dart';
import 'package:folio/core/files/recent_store.dart';
import 'package:folio/core/settings/settings_store.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/settings/settings_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

void main() {
  const channel = MethodChannel('folio/defaults');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('permite cambiar el tema y muestra versión y licencias',
      (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);

    await tester.pumpWidget(
      AppScope(
        recents: recents,
        settings: settings,
        intake: FileIntake(),
        child: MaterialApp(
          theme: FolioTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('Licencias de terceros'), findsOneWidget);
    expect(settings.themeMode, ThemeMode.system);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.light);
  });

  testWidgets(
      'muestra los tres estados de app predeterminada, sus acciones y refresca al volver',
      (tester) async {
    final prefs = await _createPrefs();
    final recents = RecentStore(prefs);
    final settings = SettingsStore(prefs);
    final calls = <MethodCall>[];
    var excelState = 'none';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'status') {
        return [
          {'kind': 'pdf', 'state': 'folio'},
          {
            'kind': 'word',
            'state': 'other',
            'appName': 'Adobe Acrobat',
            'package': 'com.adobe.reader',
          },
          {'kind': 'excel', 'state': excelState},
          {'kind': 'powerpoint', 'state': 'folio'},
        ];
      }
      return null;
    });

    await tester.pumpWidget(
      AppScope(
        recents: recents,
        settings: settings,
        intake: FileIntake(),
        child: MaterialApp(
          theme: FolioTheme.light(),
          home: SettingsScreen(defaultApps: DefaultApps(channel: channel)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABRIR DOCUMENTOS'), findsOneWidget);
    // «PDF» aparece en la insignia y como nombre del tipo.
    expect(find.text('PDF'), findsNWidgets(2));
    expect(find.text('Word'), findsOneWidget);
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('PowerPoint'), findsOneWidget);
    // "Folio" aparece en las 2 filas configuradas y en "Acerca de".
    expect(find.text('Folio'), findsNWidgets(3));
    expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
    expect(find.text('Ahora: Adobe Acrobat'), findsOneWidget);
    expect(find.text('Sin app elegida'), findsOneWidget);

    await tester.tap(find.text('Elegir Folio'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.method == 'choose').single.arguments,
      {'kind': 'excel'},
    );

    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Primero quita Adobe Acrobat como predeterminada'),
      findsOneWidget,
    );

    await tester.tap(find.text('Abrir ajustes de Adobe Acrobat'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.method == 'openAppSettings').single.arguments,
      {'package': 'com.adobe.reader'},
    );

    excelState = 'folio';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Sin app elegida'), findsNothing);
    expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
  });
}
