import 'package:flutter/widgets.dart';

import 'files/file_intake.dart';
import 'files/recent_store.dart';
import 'settings/settings_store.dart';

/// Servicios compartidos de la app. Uso: `AppScope.of(context).recents`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.recents,
    required this.settings,
    required this.intake,
    required super.child,
  });

  final RecentStore recents;
  final SettingsStore settings;
  final FileIntake intake;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay AppScope sobre este contexto');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      recents != oldWidget.recents ||
      settings != oldWidget.settings ||
      intake != oldWidget.intake;
}
