import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/folio_colors.dart';
import '../../../core/theme/folio_tokens.dart';

/// Diálogo para solicitar la contraseña de un PDF cifrado.
///
/// Devuelve la contraseña escrita al pulsar "Abrir" o `null` al pulsar
/// "Cancelar".
class PdfPasswordDialog extends StatefulWidget {
  const PdfPasswordDialog({
    super.key,
    this.incorrectPassword = false,
  });

  /// Si es `true`, muestra el aviso de contraseña incorrecta.
  final bool incorrectPassword;

  /// Muestra el diálogo y devuelve la contraseña introducida o `null` si se
  /// cancela.
  static Future<String?> show(
    BuildContext context, {
    bool incorrectPassword = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdfPasswordDialog(incorrectPassword: incorrectPassword),
    );
  }

  @override
  State<PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<PdfPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FolioTokens.rMd),
      borderSide: BorderSide(color: folio.danger),
    );

    return AlertDialog(
      title: const Text('Documento protegido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscurePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              errorText:
                  widget.incorrectPassword ? 'Contraseña incorrecta' : null,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder.copyWith(
                borderSide: BorderSide(color: folio.danger, width: 1.5),
              ),
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: FolioTokens.iconList,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}
