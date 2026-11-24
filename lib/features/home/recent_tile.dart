import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/files/document_ref.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import '../../ui/doc_badge.dart';
import '../../ui/format.dart';

enum _RecentTileAction { share, remove }

/// Fila de un documento reciente con insignia, metadatos y menú contextual.
class RecentTile extends StatelessWidget {
  const RecentTile({
    super.key,
    required this.document,
    required this.now,
    required this.onTap,
    required this.onShare,
    required this.onRemove,
  });

  final DocumentRef document;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metadata =
        '${formatBytes(document.sizeBytes)} · ${formatOpenedAt(document.openedAt, now: now)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FolioTokens.rMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: FolioTokens.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FolioTokens.s8,
            vertical: FolioTokens.s8,
          ),
          child: Row(
            children: [
              DocBadge(document.kind),
              const SizedBox(width: FolioTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: FolioTokens.s4 / 2),
                    Text(
                      metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_RecentTileAction>(
                tooltip: 'Más opciones',
                icon: Icon(
                  LucideIcons.ellipsisVertical,
                  size: FolioTokens.iconList,
                  color: context.folio.textSecondary,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _RecentTileAction.share:
                      onShare();
                    case _RecentTileAction.remove:
                      onRemove();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _RecentTileAction.share,
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.share2,
                          size: FolioTokens.iconList,
                          color: context.folio.textPrimary,
                        ),
                        const SizedBox(width: FolioTokens.s12),
                        const Text('Compartir'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _RecentTileAction.remove,
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: FolioTokens.iconList,
                          color: context.folio.textPrimary,
                        ),
                        const SizedBox(width: FolioTokens.s12),
                        const Text('Quitar de recientes'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
