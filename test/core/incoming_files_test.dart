import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/doc_kind.dart';
import 'package:folio/core/files/incoming_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('folio/incoming');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('IncomingFile.fromMap', () {
    test('construye cuando path y name son válidos', () {
      final file = IncomingFile.fromMap({
        'path': '/cache/incoming/informe.pdf',
        'name': 'informe.pdf',
      });
      expect(
        file,
        const IncomingFile(
          path: '/cache/incoming/informe.pdf',
          name: 'informe.pdf',
        ),
      );
    });

    test('construye con uri opcional cuando viene en el mapa', () {
      final file = IncomingFile.fromMap({
        'path': '/cache/incoming/carta.docx',
        'name': 'carta.docx',
        'uri': 'content://com.whatsapp.provider.media/item/1',
      });
      expect(
        file,
        const IncomingFile(
          path: '/cache/incoming/carta.docx',
          name: 'carta.docx',
          uri: 'content://com.whatsapp.provider.media/item/1',
        ),
      );
      expect(
        IncomingFile.fromMap({
          'path': '/cache/incoming/carta.docx',
          'name': 'carta.docx',
          'uri': '',
        })?.uri,
        isNull,
      );
    });

    test('devuelve null con mapas incompletos o inválidos', () {
      expect(IncomingFile.fromMap(null), isNull);
      expect(IncomingFile.fromMap({}), isNull);
      expect(IncomingFile.fromMap({'path': '/a/b.pdf'}), isNull);
      expect(IncomingFile.fromMap({'name': 'b.pdf'}), isNull);
      expect(IncomingFile.fromMap({'path': '', 'name': 'b.pdf'}), isNull);
      expect(IncomingFile.fromMap({'path': '/a/b.pdf', 'name': ''}), isNull);
      expect(IncomingFile.fromMap({'path': 123, 'name': 'b.pdf'}), isNull);
      expect(IncomingFile.fromMap({'path': '/a/b.pdf', 'name': null}), isNull);
    });
  });

  group('IncomingFiles', () {
    test('initial() devuelve el archivo del canal', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitial') {
          return {'path': '/cache/incoming/acta.docx', 'name': 'acta.docx'};
        }
        return null;
      });

      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      expect(
        await incoming.initial(),
        const IncomingFile(
          path: '/cache/incoming/acta.docx',
          name: 'acta.docx',
        ),
      );
    });

    test('initial() devuelve null si no hay intent inicial', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      expect(await incoming.initial(), isNull);
    });

    test('onFile emite en el stream files', () async {
      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      final futureFile = incoming.files.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onFile', {
            'path': '/cache/incoming/datos.xlsx',
            'name': 'datos.xlsx',
          }),
        ),
        (_) {},
      );

      expect(
        await futureFile,
        const IncomingFile(
          path: '/cache/incoming/datos.xlsx',
          name: 'datos.xlsx',
        ),
      );
    });

    test('onError emite en el stream errors', () async {
      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      final futureError = incoming.errors.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onError', {'message': 'Permiso denegado'}),
        ),
        (_) {},
      );

      expect(await futureError, 'Permiso denegado');
    });

    test('pick() devuelve IncomingFile con uri cuando se elige un archivo', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pick') {
          return {
            'path': '/cache/incoming/carta.docx',
            'name': 'carta.docx',
            'uri': 'file:///storage/emulated/0/Download/carta.docx',
          };
        }
        return null;
      });

      final file = await IncomingFiles.pick();
      expect(
        file,
        const IncomingFile(
          path: '/cache/incoming/carta.docx',
          name: 'carta.docx',
          uri: 'file:///storage/emulated/0/Download/carta.docx',
        ),
      );
    });

    test('pick() devuelve null cuando el usuario cancela', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      expect(await IncomingFiles.pick(), isNull);
    });

    test('pick() devuelve null si el selector está ocupado (busy)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'busy', message: 'Selector abierto');
      });

      expect(await IncomingFiles.pick(), isNull);
    });

    test('pick() propaga errores nativos distintos de busy', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'pick_error', message: 'Fallo al copiar');
      });

      await expectLater(IncomingFiles.pick(), throwsA(isA<PlatformException>()));
    });

    test('pick() no pisa el handler de una instancia activa de IncomingFiles', () async {
      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      expect(await IncomingFiles.pick(channel: channel), isNull);

      final futureFile = incoming.files.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onFile', {
            'path': '/cache/incoming/nota.pdf',
            'name': 'nota.pdf',
          }),
        ),
        (_) {},
      );

      expect(
        await futureFile,
        const IncomingFile(path: '/cache/incoming/nota.pdf', name: 'nota.pdf'),
      );
    });

    test('initial() emite en defaultChosen y devuelve null para muestras',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitial') {
          return {'defaultChosen': 'pdf'};
        }
        return null;
      });

      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      final futureChosen = incoming.defaultChosen.first;
      expect(await incoming.initial(), isNull);
      expect(await futureChosen, DocKind.pdf);
    });

    test('onDefaultChosen emite en el stream defaultChosen y no en files',
        () async {
      final incoming = IncomingFiles(channel: channel);
      addTearDown(incoming.dispose);

      final files = <IncomingFile>[];
      final sub = incoming.files.listen(files.add);
      addTearDown(sub.cancel);

      final futureChosen = incoming.defaultChosen.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onDefaultChosen', {'kind': 'powerpoint'}),
        ),
        (_) {},
      );

      expect(await futureChosen, DocKind.powerpoint);
      expect(files, isEmpty);
    });
  });
}
