import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/files/source_location.dart';

void main() {
  group('describeSource', () {
    test('devuelve null para null o vacío', () {
      expect(describeSource(null), isNull);
      expect(describeSource(''), isNull);
      expect(describeSource('   '), isNull);
    });

    test('formatea almacenamiento principal de externalstorage', () {
      expect(
        describeSource(
          'content://com.android.externalstorage.documents/document/primary%3ADownload%2Fcarta.docx',
        ),
        '/storage/emulated/0/Download/carta.docx',
      );
      expect(
        describeSource(
          'content://com.android.externalstorage.documents/document/primary%3ADocuments%2Fmi%20archivo.pdf',
        ),
        '/storage/emulated/0/Documents/mi archivo.pdf',
      );
    });

    test('formatea otros volúmenes externos (tarjeta SD / USB)', () {
      expect(
        describeSource(
          'content://com.android.externalstorage.documents/document/1234-5678%3ADescargas%2Fhoja.xlsx',
        ),
        '/storage/1234-5678/Descargas/hoja.xlsx',
      );
    });

    test('formatea URIs file://', () {
      expect(
        describeSource('file:///storage/emulated/0/Documents/a.pdf'),
        '/storage/emulated/0/Documents/a.pdf',
      );
    });

    test('reconoce proveedor de Descargas', () {
      expect(
        describeSource(
          'content://com.android.providers.downloads.documents/document/42',
        ),
        'Descargas',
      );
    });

    test('reconoce WhatsApp, Gmail, Google Drive y media', () {
      expect(
        describeSource(
          'content://com.whatsapp.provider.media/item/12345',
        ),
        'Compartido desde WhatsApp',
      );
      expect(
        describeSource(
          'content://com.google.android.gm.sapi/user/attachment/1',
        ),
        'Adjunto de Gmail',
      );
      expect(
        describeSource(
          'content://com.google.android.apps.docs.storage/document/abc',
        ),
        'Google Drive',
      );
      expect(
        describeSource(
          'content://com.android.providers.media.documents/document/document%3A99',
        ),
        'Almacenamiento del teléfono',
      );
      expect(
        describeSource('content://media/external/file/99'),
        'Almacenamiento del teléfono',
      );
    });

    test('indica la autoridad para otras apps content://', () {
      expect(
        describeSource(
          'content://org.telegram.messenger.provider/media/doc.pdf',
        ),
        'Compartido desde otra app (org.telegram.messenger.provider)',
      );
    });
  });
}
