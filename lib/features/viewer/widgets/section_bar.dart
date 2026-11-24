import 'package:flutter/material.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

/// Barra inferior desplazable con las secciones del documento (hojas de Excel).
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.sections,
    required this.currentSection,
    required this.onSelectSection,
  });

  final List<String> sections;
  final int currentSection;
  final ValueChanged<int> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: folio.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: folio.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: FolioTokens.s16,
                vertical: FolioTokens.s4,
              ),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(width: FolioTokens.s8),
              itemBuilder: (context, index) {
                final selected = index == currentSection;
                return ChoiceChip(
                  label: Text(sections[index]),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: folio.surfaceMuted,
                  selectedColor: folio.ink,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FolioTokens.rSm),
                  ),
                  labelStyle: textTheme.labelMedium?.copyWith(
                    color: selected ? folio.onInk : folio.textPrimary,
                  ),
                  onSelected: (_) => onSelectSection(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
