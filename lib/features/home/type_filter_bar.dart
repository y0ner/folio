import 'package:flutter/material.dart';

import '../../core/files/doc_kind.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';

/// Barra horizontal de chips para filtrar recientes por tipo de documento.
class TypeFilterBar extends StatelessWidget {
  const TypeFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DocKind? selected;
  final ValueChanged<DocKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: FolioTokens.gutter),
      child: Row(
        children: [
          _FilterChipItem(
            label: 'Todos',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final kind in DocKind.values) ...[
            const SizedBox(width: FolioTokens.s8),
            _FilterChipItem(
              label: kind.label,
              dotColor: kind.color(context),
              selected: selected == kind,
              onTap: () => onSelected(selected == kind ? null : kind),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? context.folio.onInk : context.folio.textPrimary,
        );

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: FolioTokens.s8,
              height: FolioTokens.s8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: FolioTokens.s8),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}
