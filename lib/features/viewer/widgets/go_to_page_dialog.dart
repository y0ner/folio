import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/folio_colors.dart';

/// Diálogo para saltar directamente a una página entre 1 y [pageCount].
class GoToPageDialog extends StatefulWidget {
  const GoToPageDialog({
    super.key,
    required this.pageCount,
  });

  final int pageCount;

  @override
  State<GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<GoToPageDialog> {
  final _textController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_textController.text.trim());
    if (parsed == null || parsed < 1 || parsed > widget.pageCount) {
      setState(() {
        _errorText = 'Escribe un número entre 1 y ${widget.pageCount}';
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Ir a la página'),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: '1 – ${widget.pageCount}',
          errorText: _errorText,
          errorStyle: textTheme.bodySmall?.copyWith(color: folio.danger),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ir'),
        ),
      ],
    );
  }
}
