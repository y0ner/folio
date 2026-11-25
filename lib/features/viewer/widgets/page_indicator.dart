import 'package:flutter/material.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

/// Píldora flotante que muestra la página actual sobre el total y abre el
/// salto de página al tocarla.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onTap,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: folio.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Semantics(
      button: true,
      label: 'Página $currentPage de $pageCount. Toca para ir a otra página.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FolioTokens.minTouch,
            minHeight: FolioTokens.minTouch,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: folio.surface,
                borderRadius: BorderRadius.circular(FolioTokens.rPill),
                border: Border.all(color: folio.border),
                boxShadow: folio.floatingShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FolioTokens.s16,
                  vertical: FolioTokens.s8,
                ),
                child: Text(
                  '$currentPage / $pageCount',
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
