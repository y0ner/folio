import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/files/file_intake.dart';
import 'core/files/recent_store.dart';
import 'core/settings/settings_store.dart';
import 'features/settings/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  runApp(AppScope(
    recents: RecentStore(prefs),
    settings: SettingsStore(prefs),
    intake: FileIntake(),
    child: const FolioApp(),
  ));
}
