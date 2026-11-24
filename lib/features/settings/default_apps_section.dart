import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/defaults/default_apps.dart';
import '../../core/files/doc_kind.dart';
import '../../core/theme/folio_colors.dart';
import '../../core/theme/folio_tokens.dart';
import '../../ui/doc_badge.dart';
import '../../ui/section_header.dart';

/// Devuelve el nombre visible de la app predeterminada o su paquete.
String defaultAppDisplayName(DefaultAppStatus status) {
  final name = status.appName;
  if (name != null && name.isNotEmpty) return name;
  final pkg = status.packageName;
  if (pkg != null && pkg.isNotEmpty) return pkg;
  return 'otra app';
}

/// Muestra las instrucciones para quitar otra app predeterminada y volver a elegir Folio.
Future<bool> showChangeDefaultAppDialog(
  BuildContext context,
  DefaultAppStatus status,
) async {
  final appLabel = defaultAppDisplayName(status);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Cambiar app para ${status.kind.label}'),
      content: Text(
        'Primero quita $appLabel como predeterminada: en la pantalla que '
        'se abrirá toca «Abrir de forma predeterminada» y luego «Borrar '
        'valores predeterminados». Después vuelve y toca «Elegir Folio».',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Abrir ajustes de $appLabel',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Sección de Ajustes que muestra la app predeterminada para cada tipo de documento.
class DefaultAppsSection extends StatelessWidget {
  const DefaultAppsSection({
    super.key,
    required this.statuses,
    required this.onChoose,
    required this.onChangeOther,
  });

  final List<DefaultAppStatus> statuses;
  final ValueChanged<DocKind> onChoose;
  final ValueChanged<DefaultAppStatus> onChangeOther;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Abrir documentos'),
        Container(
          decoration: BoxDecoration(
            color: context.folio.surface,
            borderRadius: BorderRadius.circular(FolioTokens.rMd),
            border: Border.all(color: context.folio.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var i = 0; i < statuses.length; i++) ...[
                  if (i > 0) const Divider(),
                  _DefaultAppRow(
                    status: statuses[i],
                    onChoose: () => onChoose(statuses[i].kind),
                    onChangeOther: () => onChangeOther(statuses[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultAppRow extends StatelessWidget {
  const _DefaultAppRow({
    required this.status,
    required this.onChoose,
    required this.onChangeOther,
  });

  final DefaultAppStatus status;
  final VoidCallback onChoose;
  final VoidCallback onChangeOther;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: FolioTokens.minTouch),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FolioTokens.s16,
          vertical: FolioTokens.s12,
        ),
        child: Row(
          children: [
            DocBadge(status.kind),
            const SizedBox(width: FolioTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status.kind.label, style: textTheme.bodyLarge),
                  const SizedBox(height: FolioTokens.s4 / 2),
                  _StatusSubtitle(status: status),
                ],
              ),
            ),
            if (status.state == DefaultState.none) ...[
              const SizedBox(width: FolioTokens.s8),
              TextButton(
                onPressed: onChoose,
                child: const Text('Elegir Folio'),
              ),
            ] else if (status.state == DefaultState.other) ...[
              const SizedBox(width: FolioTokens.s8),
              TextButton(
                onPressed: onChangeOther,
                child: const Text('Cambiar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSubtitle extends StatelessWidget {
  const _StatusSubtitle({required this.status});

  final DefaultAppStatus status;

  @override
  Widget build(BuildContext context) {
    final labelMedium = Theme.of(context).textTheme.labelMedium;
    return switch (status.state) {
      DefaultState.folio => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.check,
              size: FolioTokens.s16,
              color: context.folio.accent,
            ),
            const SizedBox(width: FolioTokens.s4),
            Text('Folio', style: labelMedium),
          ],
        ),
      DefaultState.other => Text(
          'Ahora: ${defaultAppDisplayName(status)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelMedium,
        ),
      DefaultState.none => Text('Sin app elegida', style: labelMedium),
    };
  }
}
