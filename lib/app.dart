import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/theme/folio_theme.dart';
import 'features/home/home_screen.dart';

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Folio',
        debugShowCheckedModeBanner: false,
        theme: FolioTheme.light(),
        darkTheme: FolioTheme.dark(),
        themeMode: settings.themeMode,
        home: const HomeScreen(),
      ),
    );
  }
}
