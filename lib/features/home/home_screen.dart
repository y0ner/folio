import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_scope.dart';
import '../../core/defaults/default_apps.dart';
import '../../core/files/doc_kind.dart';
import '../../core/files/document_ref.dart';
import '../../core/files/file_intake.dart';
import '../../core/open_document.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import '../../ui/empty_state.dart';
import '../../ui/section_header.dart';
import '../settings/settings_screen.dart';
import 'defaults_banner.dart';
import 'recent_groups.dart';
import 'recent_tile.dart';
import 'type_filter_bar.dart';

/// Pantalla principal de Folio: búsqueda, filtros y lista de recientes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.defaultApps});

  final DefaultApps? defaultApps;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultsDismissedKey = 'home.defaultsBannerDismissed';

  final TextEditingController _searchController = TextEditingController();
  late final DefaultApps _defaultApps = widget.defaultApps ?? DefaultApps();
  late final AppLifecycleListener _lifecycle;
  String _query = '';
  DocKind? _selectedKind;
  bool _picking = false;
  bool _showDefaultsBanner = false;
  bool _defaultsBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshDefaultsBanner);
    _loadDefaultsBanner();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultsBanner() async {
    try {
      final dismissed =
          await SharedPreferencesAsync().getBool(_defaultsDismissedKey) ??
              false;
      if (!mounted) return;
      if (dismissed) {
        setState(() {
          _defaultsBannerDismissed = true;
          _showDefaultsBanner = false;
        });
        return;
      }
    } catch (e, st) {
      debugPrint('HomeScreen: error leyendo preferencia de aviso: $e\n$st');
    }
    await _refreshDefaultsBanner();
  }

  Future<void> _refreshDefaultsBanner() async {
    if (_defaultsBannerDismissed) return;
    try {
      final statuses = await _defaultApps.status();
      if (!mounted || _defaultsBannerDismissed) return;
      final shouldShow = statuses.isNotEmpty &&
          statuses.any((s) => s.state != DefaultState.folio);
      if (shouldShow != _showDefaultsBanner) {
        setState(() => _showDefaultsBanner = shouldShow);
      }
    } catch (e, st) {
      debugPrint(
        'HomeScreen: error consultando apps predeterminadas: $e\n$st',
      );
    }
  }

  Future<void> _dismissDefaultsBanner() async {
    setState(() {
      _defaultsBannerDismissed = true;
      _showDefaultsBanner = false;
    });
    try {
      await SharedPreferencesAsync().setBool(_defaultsDismissedKey, true);
    } catch (e, st) {
      debugPrint('HomeScreen: error guardando cierre de aviso: $e\n$st');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(defaultApps: widget.defaultApps),
      ),
    );
    if (mounted) {
      await _refreshDefaultsBanner();
    }
  }

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final scope = AppScope.of(context);
      final result = await scope.intake.pick();
      if (!mounted) return;
      switch (result) {
        case IntakeOpened(:final document):
          await openDocument(context, document);
        case IntakeUnsupported(:final name):
          _showSnackBar('Folio no puede abrir «$name»');
        case IntakeCancelled():
          break;
      }
    } catch (e, st) {
      debugPrint('HomeScreen: error al abrir archivo: $e\n$st');
      if (!mounted) return;
      _showSnackBar('No se pudo abrir el archivo');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _openRecent(DocumentRef doc) async {
    if (!File(doc.path).existsSync()) {
      _showMissingFileSnackBar(doc);
      return;
    }
    await openDocument(context, doc);
  }

  Future<void> _shareRecent(DocumentRef doc) async {
    if (!File(doc.path).existsSync()) {
      _showMissingFileSnackBar(doc);
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(doc.path)]));
    } catch (e, st) {
      debugPrint('HomeScreen: error al compartir ${doc.path}: $e\n$st');
      if (!mounted) return;
      _showSnackBar('No se pudo compartir el archivo');
    }
  }

  Future<void> _removeRecent(DocumentRef doc) async {
    final scope = AppScope.of(context);
    try {
      await scope.recents.remove(doc);
      await scope.intake.deleteLocalCopy(doc);
    } catch (e, st) {
      debugPrint('HomeScreen: error al quitar ${doc.path}: $e\n$st');
      if (!mounted) return;
      _showSnackBar('No se pudo quitar el archivo de recientes');
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMissingFileSnackBar(DocumentRef doc) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Este archivo ya no está disponible'),
        action: SnackBarAction(
          label: 'Quitar',
          textColor: context.folio.onInk,
          onPressed: () => _removeRecent(doc),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final bottomSpace =
        FolioTokens.s48 + FolioTokens.s48 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _OpenFileButton(
        loading: _picking,
        onPressed: _pickFile,
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: scope.recents,
          builder: (context, _) {
            final allItems = scope.recents.items;
            final filtered = filterRecents(
              allItems,
              query: _query,
              kind: _selectedKind,
            );
            final now = DateTime.now();
            final groups = groupRecents(filtered, now: now);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    FolioTokens.gutter,
                    FolioTokens.s16,
                    FolioTokens.s8,
                    FolioTokens.s12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Folio',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _openSettings,
                          icon: const Icon(
                            LucideIcons.settings2,
                            size: FolioTokens.iconBar,
                          ),
                          tooltip: 'Ajustes',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FolioTokens.gutter,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar en recientes',
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: FolioTokens.iconList,
                          color: context.folio.textTertiary,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: Icon(
                                  LucideIcons.x,
                                  size: FolioTokens.iconList,
                                  color: context.folio.textSecondary,
                                ),
                                tooltip: 'Limpiar búsqueda',
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: FolioTokens.s12,
                    bottom: FolioTokens.s8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: TypeFilterBar(
                      selected: _selectedKind,
                      onSelected: (kind) =>
                          setState(() => _selectedKind = kind),
                    ),
                  ),
                ),
                if (_showDefaultsBanner)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      FolioTokens.gutter,
                      FolioTokens.s8,
                      FolioTokens.gutter,
                      FolioTokens.s8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: DefaultsBanner(
                        onChoose: _openSettings,
                        onDismiss: _dismissDefaultsBanner,
                      ),
                    ),
                  ),
                if (allItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomSpace),
                      child: const EmptyState(
                        icon: LucideIcons.fileText,
                        title: 'Abre tu primer documento',
                        subtitle:
                            'PDF, Word, Excel y PowerPoint, sin conexión.',
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomSpace),
                      child: const EmptyState(
                        icon: LucideIcons.search,
                        title: 'Sin resultados',
                      ),
                    ),
                  )
                else ...[
                  for (final group in groups) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FolioTokens.gutter,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: SectionHeader(group.label),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FolioTokens.gutter - FolioTokens.s8,
                      ),
                      sliver: SliverList.builder(
                        itemCount: group.items.length,
                        itemBuilder: (context, index) {
                          final doc = group.items[index];
                          return RecentTile(
                            key: ValueKey(doc.path),
                            document: doc,
                            now: now,
                            onTap: () => _openRecent(doc),
                            onShare: () => _shareRecent(doc),
                            onRemove: () => _removeRecent(doc),
                          );
                        },
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: bottomSpace),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpenFileButton extends StatelessWidget {
  const _OpenFileButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: context.isDark
              ? BorderSide(color: context.folio.border)
              : BorderSide.none,
        ),
        shadows: context.folio.floatingShadow,
      ),
      child: FilledButton.icon(
        onPressed: loading ? () {} : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: FolioTokens.s20),
        ),
        icon: loading
            ? SizedBox(
                width: FolioTokens.iconList,
                height: FolioTokens.iconList,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.folio.onInk,
                ),
              )
            : const Icon(LucideIcons.folderOpen, size: FolioTokens.iconList),
        label: const Text('Abrir archivo'),
      ),
    );
  }
}
