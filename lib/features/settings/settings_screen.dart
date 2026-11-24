import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_scope.dart';
import '../../core/defaults/default_apps.dart';
import '../../core/files/doc_kind.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import '../../ui/section_header.dart';
import 'default_apps_section.dart';

/// Pantalla de ajustes de Folio: apariencia, apps predeterminadas y licencias.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.defaultApps});

  final DefaultApps? defaultApps;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '1.0.0';

  late final DefaultApps _defaultApps = widget.defaultApps ?? DefaultApps();
  late final AppLifecycleListener _lifecycle;
  List<DefaultAppStatus> _statuses = const [];
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _loadStatuses);
    _loadStatuses();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    final seq = ++_loadSeq;
    try {
      final result = await _defaultApps.status();
      if (!mounted || seq != _loadSeq) return;
      setState(() => _statuses = result);
    } catch (e, st) {
      debugPrint('SettingsScreen: error consultando apps predeterminadas: $e\n$st');
    }
  }

  Future<void> _choose(DocKind kind) async {
    try {
      await _defaultApps.choose(kind);
    } catch (e, st) {
      debugPrint('SettingsScreen: error al elegir app para ${kind.name}: $e\n$st');
      if (!mounted) return;
      _showSnackBar('No se pudo abrir el selector de aplicaciones');
    }
  }

  Future<void> _changeOther(DefaultAppStatus status) async {
    final openSettings = await showChangeDefaultAppDialog(context, status);
    if (!mounted || !openSettings) return;

    final packageName = status.packageName;
    if (packageName == null || packageName.isEmpty) {
      _showSnackBar('No se pudo identificar la aplicación');
      return;
    }

    try {
      await _defaultApps.openAppSettings(packageName);
    } catch (e, st) {
      debugPrint(
        'SettingsScreen: error abriendo ajustes de $packageName: $e\n$st',
      );
      if (!mounted) return;
      _showSnackBar('No se pudieron abrir los ajustes de la aplicación');
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
          if (_statuses.isNotEmpty) ...[
            DefaultAppsSection(
              statuses: _statuses,
              onChoose: _choose,
              onChangeOther: _changeOther,
            ),
            const SizedBox(height: FolioTokens.s16),
          ],
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
