import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';
import '../viewer_controller.dart';
import '../viewer_messages.dart';

/// Vista de error que cubre el cuerpo del visor con una explicación clara y
/// una acción principal.
class ViewerErrorView extends StatelessWidget {
  const ViewerErrorView({
    super.key,
    required this.failure,
    required this.onShare,
    required this.onBack,
  });

  final ViewerFailure failure;
  final VoidCallback onShare;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;
    final message = messageFor(failure.kind);
    final isMissing = failure.kind == ViewerFailureKind.missing;

    final icon = switch (failure.kind) {
      ViewerFailureKind.encrypted => LucideIcons.lock,
      ViewerFailureKind.missing => LucideIcons.fileQuestion,
      _ => LucideIcons.fileX,
    };

    return ColoredBox(
      color: folio.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FolioTokens.s32,
            kToolbarHeight + FolioTokens.s24,
            FolioTokens.s32,
            FolioTokens.s32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: folio.textSecondary,
                  ),
                  const SizedBox(height: FolioTokens.s16),
                  Text(
                    message.title,
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: FolioTokens.s8),
                  Text(
                    message.body,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: FolioTokens.s24),
                  FilledButton(
                    onPressed: isMissing ? onBack : onShare,
                    child: Text(
                      isMissing ? 'Volver' : 'Compartir con otra app',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
