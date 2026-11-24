import 'package:flutter/material.dart';

import '../core/files/doc_kind.dart';

/// Insignia cuadrada con la abreviatura y el color del tipo de documento.
class DocBadge extends StatelessWidget {
  const DocBadge(this.kind, {super.key, this.size = 40});

  final DocKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: kind.color(context),
        );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kind.tint(context),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(kind.abbreviation, style: style),
      ),
    );
  }
}
