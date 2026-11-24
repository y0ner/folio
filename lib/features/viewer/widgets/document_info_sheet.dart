import 'package:flutter/material.dart';

import '../../../core/files/document_ref.dart';
import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

/// Hoja inferior con los metadatos del documento abierto.
class DocumentInfoSheet extends StatelessWidget {
  const DocumentInfoSheet({
    super.key,
    required this.document,
    required this.pageCount,
  });

  final DocumentRef document;
  final int pageCount;

  /// Formatea un tamaño en bytes a B, KB o MB con coma decimal.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1).replaceAll('.', ',');
      return '$kb KB';
    }
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    return '$mb MB';
  }

  /// Formatea una fecha como `dd/mm/aaaa hh:mm` sin depender de `intl`.
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final folio = context.folio;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FolioTokens.gutter,
          0,
          FolioTokens.gutter,
          FolioTokens.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Información del archivo',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: FolioTokens.s16),
            _InfoRow(label: 'Nombre', value: document.name),
            Divider(color: folio.border),
            _InfoRow(label: 'Tipo', value: document.kind.label),
            Divider(color: folio.border),
            _InfoRow(label: 'Tamaño', value: formatSize(document.sizeBytes)),
            Divider(color: folio.border),
            _InfoRow(
              label: 'Abierto',
              value: formatDateTime(document.openedAt),
            ),
            if (pageCount > 0) ...[
              Divider(color: folio.border),
              _InfoRow(label: 'Páginas', value: '$pageCount'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FolioTokens.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          const SizedBox(width: FolioTokens.s12),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
