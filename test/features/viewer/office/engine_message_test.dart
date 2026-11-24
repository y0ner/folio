import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/viewer/office/engine_message.dart';
import 'package:folio/features/viewer/viewer_controller.dart';

void main() {
  group('EngineMessage.parse', () {
    test('interpreta ready con pageCount y sections', () {
      final msg = EngineMessage.parse({
        'type': 'ready',
        'pageCount': 12,
        'sections': ['Hoja 1', 'Resumen'],
      });
      expect(msg, const EngineReady(12, ['Hoja 1', 'Resumen']));

      final withoutSections = EngineMessage.parse({
        'type': 'ready',
        'pageCount': 0,
      });
      expect(withoutSections, const EngineReady(0));
    });

    test('interpreta page y tap', () {
      expect(
        EngineMessage.parse({'type': 'page', 'page': 3}),
        const EnginePage(3),
      );
      expect(
        EngineMessage.parse({'type': 'tap'}),
        const EngineTap(),
      );
    });

    test('interpreta error y mapea cada kind conocido y desconocido', () {
      expect(
        EngineMessage.parse({
          'type': 'error',
          'kind': 'encrypted',
          'detail': 'OLE',
        }),
        const EngineError(ViewerFailureKind.encrypted, 'OLE'),
      );
      expect(
        EngineMessage.parse({'type': 'error', 'kind': 'corrupt'}),
        const EngineError(ViewerFailureKind.corrupt),
      );
      expect(
        EngineMessage.parse({'type': 'error', 'kind': 'unsupported'}),
        const EngineError(ViewerFailureKind.unsupported),
      );
      expect(
        EngineMessage.parse({'type': 'error', 'kind': 'engine', 'detail': 'JS'}),
        const EngineError(ViewerFailureKind.engine, 'JS'),
      );
      expect(
        EngineMessage.parse({
          'type': 'error',
          'kind': 'desconocido',
          'detail': 'otro',
        }),
        const EngineError(ViewerFailureKind.engine, 'otro'),
      );
    });

    test('acepta JSON en texto', () {
      final raw = jsonEncode({'type': 'page', 'page': 7});
      expect(EngineMessage.parse(raw), const EnginePage(7));

      final readyRaw = jsonEncode({
        'type': 'ready',
        'pageCount': 4,
        'sections': [],
      });
      expect(EngineMessage.parse(readyRaw), const EngineReady(4));
    });

    test('devuelve null ante entrada o JSON inválido o campos faltantes', () {
      expect(EngineMessage.parse(null), isNull);
      expect(EngineMessage.parse(42), isNull);
      expect(EngineMessage.parse(['ready']), isNull);
      expect(EngineMessage.parse('{no es json'), isNull);
      expect(EngineMessage.parse('[1, 2, 3]'), isNull);
      expect(EngineMessage.parse({}), isNull);
      expect(EngineMessage.parse({'type': 'otro'}), isNull);

      // Campos faltantes o inválidos por tipo de mensaje.
      expect(EngineMessage.parse({'type': 'ready'}), isNull);
      expect(
        EngineMessage.parse({'type': 'ready', 'pageCount': -1}),
        isNull,
      );
      expect(
        EngineMessage.parse({'type': 'ready', 'pageCount': '3'}),
        isNull,
      );
      expect(
        EngineMessage.parse({
          'type': 'ready',
          'pageCount': 2,
          'sections': 'invalido',
        }),
        isNull,
      );
      expect(
        EngineMessage.parse({
          'type': 'ready',
          'pageCount': 2,
          'sections': [123],
        }),
        isNull,
      );

      expect(EngineMessage.parse({'type': 'page'}), isNull);
      expect(EngineMessage.parse({'type': 'page', 'page': 0}), isNull);
      expect(EngineMessage.parse({'type': 'page', 'page': '2'}), isNull);

      expect(EngineMessage.parse({'type': 'error'}), isNull);
      expect(EngineMessage.parse({'type': 'error', 'kind': 10}), isNull);
    });
  });
}
