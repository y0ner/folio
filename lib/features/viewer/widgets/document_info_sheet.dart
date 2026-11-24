import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/files/document_ref.dart';
import '../../../core/files/source_location.dart';
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

  Future<void> _copyLocation(BuildContext context, String location) async {
    await Clipboard.setData(ClipboardData(text: location));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Ruta copiada')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final folio = context.folio;
    final location = describeSource(document.source);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            Divider(color: folio.border),
            _InfoRow(
              label: 'Ubicación',
              value: location ?? 'Desconocida (abierto antes de esta versión)',
              selectable: true,
              valueStyle: location == null
                  ? textTheme.bodyLarge?.copyWith(color: folio.textSecondary)
                  : null,
              trailing: location == null
                  ? null
                  : IconButton(
                      icon: const Icon(
                        LucideIcons.copy,
                        size: FolioTokens.iconList,
                      ),
                      tooltip: 'Copiar ruta',
                      onPressed: () => _copyLocation(context, location),
                    ),
            ),
            Divider(color: folio.border),
            _InfoRow(
              label: 'Copia en Folio',
              value: document.path,
              selectable: true,
              valueStyle:
                  textTheme.labelSmall?.copyWith(color: folio.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final bool selectable;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = valueStyle ?? textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FolioTokens.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          const SizedBox(width: FolioTokens.s12),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: style,
                    textAlign: TextAlign.end,
                  )
                : Text(
                    value,
                    style: style,
                    textAlign: TextAlign.end,
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FolioTokens.s4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
