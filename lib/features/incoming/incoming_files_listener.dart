import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files/file_intake.dart';
import '../../core/files/incoming_files.dart';
import '../../core/open_document.dart';

/// Escucha archivos enviados desde otras apps y los abre en el visor.
class IncomingFilesListener extends StatefulWidget {
  const IncomingFilesListener({
    super.key,
    required this.child,
    this.incoming,
  });

  final Widget child;
  final IncomingFiles? incoming;

  @override
  State<IncomingFilesListener> createState() => _IncomingFilesListenerState();
}

class _IncomingFilesListenerState extends State<IncomingFilesListener> {
  late final IncomingFiles _incoming;
  late final bool _ownsIncoming;
  StreamSubscription<IncomingFile>? _filesSub;
  StreamSubscription<String>? _errorsSub;

  @override
  void initState() {
    super.initState();
    _ownsIncoming = widget.incoming == null;
    _incoming = widget.incoming ?? IncomingFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _filesSub = _incoming.files.listen(_handleFile);
      _errorsSub = _incoming.errors.listen(_handleError);
      _checkInitial();
    });
  }

  @override
  void dispose() {
    _filesSub?.cancel();
    _errorsSub?.cancel();
    if (_ownsIncoming) {
      _incoming.dispose();
    }
    super.dispose();
  }

  Future<void> _checkInitial() async {
    final file = await _incoming.initial();
    if (!mounted || file == null) return;
    await _handleFile(file);
  }

  Future<void> _handleFile(IncomingFile incoming) async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    final source = File(incoming.path);
    try {
      final result = await scope.intake.importFile(
        source,
        name: incoming.name,
        sourceUri: incoming.uri,
      );
      if (!mounted) return;
      switch (result) {
        case IntakeOpened(:final document):
          await openDocument(context, document);
        case IntakeUnsupported(:final name):
          _showSnackBar('Folio no puede abrir «$name»');
        case IntakeCancelled():
          break;
      }
    } catch (e) {
      debugPrint('Error al recibir archivo ${incoming.name}: $e');
      if (mounted) {
        _showSnackBar('No se pudo recibir el archivo');
      }
    } finally {
      await _deleteTempFile(source);
    }
  }

  void _handleError(String message) {
    debugPrint('Error de archivo entrante: $message');
    if (!mounted) return;
    _showSnackBar('No se pudo recibir el archivo');
  }

  Future<void> _deleteTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('No se pudo borrar copia temporal ${file.path}: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
