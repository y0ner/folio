import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/app_scope.dart';
import 'package:folio/core/files/file_intake.dart';
import 'package:folio/core/files/recent_store.dart';
import 'package:folio/core/settings/settings_store.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/settings/settings_screen.dart';
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
}
