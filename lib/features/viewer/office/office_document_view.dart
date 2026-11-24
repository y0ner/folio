import 'package:flutter/material.dart';

import '../../../core/files/document_ref.dart';
import '../viewer_controller.dart';

/// Cuerpo del visor para Word, Excel y PowerPoint (motores web empaquetados
/// en `assets/engines/`). (Se implementa en el brief W1-D.)
class OfficeDocumentView extends StatelessWidget {
  const OfficeDocumentView({
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
