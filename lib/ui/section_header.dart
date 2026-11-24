import 'package:flutter/material.dart';

import '../core/theme/folio_colors.dart';
import '../core/theme/folio_tokens.dart';

/// Encabezado de sección en mayúsculas con tracking sutil.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(
      top: FolioTokens.s16,
      bottom: FolioTokens.s8,
    ),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.folio.textSecondary,
          letterSpacing: 0.6,
        );

    return Padding(
      padding: padding,
      child: Text(title.toUpperCase(), style: style),
    );
  }
}
