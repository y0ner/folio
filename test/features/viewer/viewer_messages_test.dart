import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/viewer/viewer_controller.dart';
import 'package:folio/features/viewer/viewer_messages.dart';

void main() {
  test('cada tipo de fallo tiene título y cuerpo no vacíos y distintos', () {
    final titles = <String>{};
    final bodies = <String>{};

    for (final kind in ViewerFailureKind.values) {
      final message = messageFor(kind);
      expect(message.title.trim(), isNotEmpty);
      expect(message.body.trim(), isNotEmpty);
      expect(titles.add(message.title), isTrue);
      expect(bodies.add(message.body), isTrue);
    }
  });
}
