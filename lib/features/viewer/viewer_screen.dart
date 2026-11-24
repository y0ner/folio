import 'package:flutter/material.dart';

import '../../core/files/doc_kind.dart';
import '../../core/files/document_ref.dart';
import 'office/office_document_view.dart';
import 'pdf/pdf_document_view.dart';
import 'viewer_controller.dart';

/// Pantalla del visor: barras, indicador y errores alrededor del cuerpo de
/// cada tipo. (Versión base; el brief W1-E la completa.)
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.document});

  final DocumentRef document;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = ViewerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleChrome() {}

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final body = switch (doc.kind) {
      DocKind.pdf => PdfDocumentView(
          document: doc, controller: _controller, onTap: _toggleChrome),
      _ => OfficeDocumentView(
          document: doc, controller: _controller, onTap: _toggleChrome),
    };
    return Scaffold(
      appBar: AppBar(title: Text(doc.name, overflow: TextOverflow.ellipsis)),
      body: body,
    );
  }
}
