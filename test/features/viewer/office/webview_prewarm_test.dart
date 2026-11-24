import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/viewer/office/webview_prewarm.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('prewarmWebView no hace nada y no lanza en plataformas no Android', () async {
    for (final platform in <TargetPlatform>[
      TargetPlatform.linux,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await expectLater(prewarmWebView(), completes);
    }
  });
}
