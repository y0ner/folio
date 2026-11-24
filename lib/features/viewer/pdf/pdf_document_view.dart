import 'package:flutter/material.dart';

import '../../../core/files/document_ref.dart';
import '../viewer_controller.dart';

/// Cuerpo del visor para PDF. (Se implementa en el brief W1-C.)
class PdfDocumentView extends StatelessWidget {
  const PdfDocumentView({
    super.key,
    required this.document,
    required this.controller,
    required this.onTap,
  });

  final DocumentRef document;
  final ViewerController controller;

  /// Toque simple sobre el contenido (la pantalla alterna las barras).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
