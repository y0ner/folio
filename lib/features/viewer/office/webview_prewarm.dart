import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

bool _prewarmed = false;

/// Precalienta el motor Chromium de `InAppWebView` una sola vez por proceso en
/// Android para reducir el tiempo de apertura del primer documento Office.
Future<void> prewarmWebView() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (_prewarmed) return;
  _prewarmed = true;

  HeadlessInAppWebView? headless;
  try {
    final loaded = Completer<void>();
    headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(data: '<html></html>'),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) {
          loaded.complete();
        }
      },
      onReceivedError: (_, request, error) {
        if ((request.isForMainFrame ?? true) && !loaded.isCompleted) {
          debugPrint(
            'prewarmWebView: error al cargar (${error.type}): ${error.description}',
          );
          loaded.complete();
        }
      },
    );

    await headless.run();
    await loaded.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
  } catch (error, stackTrace) {
    debugPrint('prewarmWebView: no se pudo precalentar WebView: $error');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    if (headless != null) {
      try {
        await headless.dispose();
      } catch (error) {
        debugPrint('prewarmWebView: error al liberar WebView: $error');
      }
    }
  }
}
