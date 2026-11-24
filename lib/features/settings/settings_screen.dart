import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_scope.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import '../../ui/section_header.dart';

/// Pantalla de ajustes de Folio: apariencia y licencias de terceros.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.folio.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: FolioTokens.gutter,
          vertical: FolioTokens.s12,
        ),
        children: [
          const SectionHeader(
            'Apariencia',
            padding: EdgeInsets.only(
              top: FolioTokens.s8,
              bottom: FolioTokens.s12,
            ),
          ),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  settings.setThemeMode(selection.first);
                },
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                    icon: Icon(
                      LucideIcons.monitorSmartphone,
                      size: FolioTokens.iconList,
                    ),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(
                      LucideIcons.sun,
                      size: FolioTokens.iconList,
                    ),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Oscuro'),
                    icon: Icon(
                      LucideIcons.moon,
                      size: FolioTokens.iconList,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FolioTokens.s16),
          const SectionHeader('Acerca de'),
          Container(
            decoration: BoxDecoration(
              color: context.folio.surface,
              borderRadius: BorderRadius.circular(FolioTokens.rMd),
              border: Border.all(color: context.folio.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Folio'),
                    trailing: Text(
                      _appVersion,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Licencias de terceros'),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Folio',
                      applicationVersion: _appVersion,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
