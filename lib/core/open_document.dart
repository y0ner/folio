import 'package:flutter/material.dart';

import '../features/viewer/viewer_screen.dart';
import 'app_scope.dart';
import 'files/document_ref.dart';

/// Registra [doc] en recientes y abre el visor.
Future<void> openDocument(BuildContext context, DocumentRef doc) async {
  final scope = AppScope.of(context);
  final navigator = Navigator.of(context);
  final evicted = await scope.recents.add(doc.copyWith(openedAt: DateTime.now()));
  for (final old in evicted) {
    await scope.intake.deleteLocalCopy(old);
  }
  await navigator.push(
    MaterialPageRoute<void>(builder: (_) => ViewerScreen(document: doc)),
  );
}
