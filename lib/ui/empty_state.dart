import 'package:flutter/material.dart';

import '../core/theme/folio_colors.dart';
import '../core/theme/folio_tokens.dart';

/// Estado vacío reutilizable con icono en trazo fino, título y ayuda opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FolioTokens.gutter,
          vertical: FolioTokens.s32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: FolioTokens.s48,
              color: context.folio.textTertiary,
            ),
            const SizedBox(height: FolioTokens.s16),
            Text(
              title,
              style: theme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: FolioTokens.s8),
              Text(
                subtitle!,
                style: theme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
