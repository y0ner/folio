import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';

/// Tarjeta discreta que invita al usuario a elegir Folio como visor predeterminado.
class DefaultsBanner extends StatelessWidget {
  const DefaultsBanner({
    super.key,
    required this.onChoose,
    required this.onDismiss,
  });

  final VoidCallback onChoose;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.folio.textPrimary,
        );

    return Container(
      decoration: BoxDecoration(
        color: context.folio.surface,
        borderRadius: BorderRadius.circular(FolioTokens.rMd),
        border: Border.all(color: context.folio.border),
      ),
      padding: const EdgeInsets.fromLTRB(
        FolioTokens.s16,
        FolioTokens.s8,
        FolioTokens.s8,
        FolioTokens.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Haz de Folio tu visor predeterminado',
              style: textStyle,
            ),
          ),
          const SizedBox(width: FolioTokens.s8),
          TextButton(
            onPressed: onChoose,
            child: const Text('Elegir'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              LucideIcons.x,
              size: FolioTokens.iconList,
              color: context.folio.textSecondary,
            ),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}
