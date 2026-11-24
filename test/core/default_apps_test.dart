import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/defaults/default_apps.dart';
import 'package:folio/core/files/doc_kind.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('folio/defaults');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('DefaultAppStatus.fromMap', () {
    test('mapea folio, other y none correctamente', () {
      expect(
        DefaultAppStatus.fromMap({'kind': 'pdf', 'state': 'folio'}),
        const DefaultAppStatus(kind: DocKind.pdf, state: DefaultState.folio),
      );
      expect(
        DefaultAppStatus.fromMap({
          'kind': 'word',
          'state': 'other',
          'appName': 'Google Docs',
          'package': 'com.google.android.apps.docs.editors.docs',
        }),
        const DefaultAppStatus(
          kind: DocKind.word,
          state: DefaultState.other,
          appName: 'Google Docs',
          packageName: 'com.google.android.apps.docs.editors.docs',
        ),
      );
      expect(
        DefaultAppStatus.fromMap({
          'kind': 'excel',
          'state': 'none',
          'appName': '',
          'package': '',
        }),
        const DefaultAppStatus(
          kind: DocKind.excel,
          state: DefaultState.none,
        ),
      );
    });

    test('devuelve null ante mapas incompletos o inválidos', () {
      expect(DefaultAppStatus.fromMap(null), isNull);
      expect(DefaultAppStatus.fromMap({}), isNull);
      expect(
        DefaultAppStatus.fromMap({'kind': 'desconocido', 'state': 'none'}),
        isNull,
      );
      expect(
        DefaultAppStatus.fromMap({'kind': 'pdf', 'state': 'otro'}),
        isNull,
      );
    });
  });

  group('DefaultApps', () {
    test('status() mapea la lista devuelta por el canal', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'status');
        return [
          {'kind': 'pdf', 'state': 'folio'},
          {
            'kind': 'word',
            'state': 'other',
            'appName': 'WPS Office',
            'package': 'cn.wps.moffice_eng',
          },
          {'kind': 'excel', 'state': 'none'},
          {'kind': 'powerpoint', 'state': 'invalid'},
        ];
      });

      final defaults = DefaultApps(channel: channel);
      expect(await defaults.status(), const [
        DefaultAppStatus(kind: DocKind.pdf, state: DefaultState.folio),
        DefaultAppStatus(
          kind: DocKind.word,
          state: DefaultState.other,
          appName: 'WPS Office',
          packageName: 'cn.wps.moffice_eng',
        ),
        DefaultAppStatus(kind: DocKind.excel, state: DefaultState.none),
      ]);
    });

    test('status() devuelve lista vacía cuando no es Android', () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        called = true;
        return const [];
      });

      final defaults = DefaultApps(channel: channel, isAndroid: false);
      expect(await defaults.status(), isEmpty);
      expect(called, isFalse);
    });

    test('status() devuelve lista vacía si el canal no está disponible',
        () async {
      final defaults = DefaultApps(channel: channel);
      expect(await defaults.status(), isEmpty);
    });

    test('choose() envía el tipo de documento al canal', () async {
      MethodCall? recorded;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        recorded = call;
        return null;
      });

      final defaults = DefaultApps(channel: channel);
      await defaults.choose(DocKind.powerpoint);

      expect(recorded?.method, 'choose');
      expect(recorded?.arguments, {'kind': 'powerpoint'});
    });

    test('choose() propaga PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'no_app', message: 'Sin apps');
      });

      final defaults = DefaultApps(channel: channel);
      await expectLater(
        defaults.choose(DocKind.pdf),
        throwsA(isA<PlatformException>()),
      );
    });

    test('openAppSettings() envía el paquete al canal', () async {
      MethodCall? recorded;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        recorded = call;
        return null;
      });

      final defaults = DefaultApps(channel: channel);
      await defaults.openAppSettings('com.adobe.reader');

      expect(recorded?.method, 'openAppSettings');
      expect(recorded?.arguments, {'package': 'com.adobe.reader'});
    });
  });
}
