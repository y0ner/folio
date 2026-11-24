import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/files/doc_kind.dart';
import '../../../core/files/document_ref.dart';
import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

enum _TopBarMenuAction { info, goToPage }

/// Barra superior propia del visor con navegación, tipo, nombre y acciones.
class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.document,
    required this.canGoToPage,
    required this.onBack,
    required this.onShare,
    required this.onShowInfo,
    required this.onGoToPage,
    this.onSearch,
  });

  final DocumentRef document;
  final bool canGoToPage;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback onShowInfo;
  final VoidCallback onGoToPage;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: folio.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: folio.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FolioTokens.s4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      size: FolioTokens.iconBar,
                    ),
                    tooltip: 'Atrás',
                    onPressed: onBack,
                  ),
                  _SmallDocBadge(kind: document.kind),
                  const SizedBox(width: FolioTokens.s8),
                  Expanded(
                    child: Text(
                      document.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onSearch != null)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.search,
                        size: FolioTokens.iconBar,
                      ),
                      tooltip: 'Buscar',
                      onPressed: onSearch,
                    ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.share2,
                      size: FolioTokens.iconBar,
                    ),
                    tooltip: 'Compartir',
                    onPressed: onShare,
                  ),
                  PopupMenuButton<_TopBarMenuAction>(
                    icon: const Icon(
                      LucideIcons.ellipsisVertical,
                      size: FolioTokens.iconBar,
                    ),
                    tooltip: 'Más opciones',
                    onSelected: (action) {
                      switch (action) {
                        case _TopBarMenuAction.info:
                          onShowInfo();
                        case _TopBarMenuAction.goToPage:
                          onGoToPage();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<_TopBarMenuAction>(
                        value: _TopBarMenuAction.info,
                        child: Text('Información del archivo'),
                      ),
                      if (canGoToPage)
                        const PopupMenuItem<_TopBarMenuAction>(
                          value: _TopBarMenuAction.goToPage,
                          child: Text('Ir a la página…'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallDocBadge extends StatelessWidget {
  const _SmallDocBadge({required this.kind});

  final DocKind kind;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: kind.color(context),
          fontWeight: FontWeight.w600,
        );

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: kind.tint(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          kind.abbreviation,
          style: labelStyle,
          maxLines: 1,
        ),
      ),
    );
  }
}
