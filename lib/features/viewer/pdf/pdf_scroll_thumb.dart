import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

/// Indicador vertical en forma de píldora para desplazarse rápidamente por las
/// páginas de un PDF.
class FolioPdfScrollThumb extends StatelessWidget {
  const FolioPdfScrollThumb({
    super.key,
    required this.controller,
  });

  final PdfViewerController controller;

  static const Size _thumbSize = Size(48, 32);

  @override
  Widget build(BuildContext context) {
    return PdfViewerScrollThumb(
      controller: controller,
      orientation: ScrollbarOrientation.right,
      margin: FolioTokens.s8,
      thumbSize: _thumbSize,
      thumbBuilder: (context, thumbSize, pageNumber, pdfController) {
        final folio = context.folio;
        final currentPage = pageNumber ?? pdfController.pageNumber;
        final label = currentPage != null ? '$currentPage' : '';
        return DecoratedBox(
          decoration: BoxDecoration(
            color: folio.surface,
            borderRadius: BorderRadius.circular(FolioTokens.rPill),
            border: Border.all(color: folio.border),
            boxShadow: folio.floatingShadow,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FolioTokens.s4),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: folio.textPrimary,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
