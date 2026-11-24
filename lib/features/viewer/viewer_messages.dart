import 'viewer_controller.dart';

/// Mensajes de error legibles para el usuario según [ViewerFailureKind].
({String title, String body}) messageFor(ViewerFailureKind kind) {
  return switch (kind) {
    ViewerFailureKind.encrypted => (
        title: 'Documento protegido',
        body: 'Este archivo tiene contraseña y no se puede mostrar.',
      ),
    ViewerFailureKind.corrupt => (
        title: 'No se pudo abrir el archivo',
        body: 'Parece estar dañado o incompleto.',
      ),
    ViewerFailureKind.unsupported => (
        title: 'Formato no compatible',
        body: 'Folio aún no puede mostrar este tipo de archivo.',
      ),
    ViewerFailureKind.missing => (
        title: 'El archivo ya no está',
        body: 'Se movió o se borró del dispositivo.',
      ),
    ViewerFailureKind.engine => (
        title: 'Algo salió mal',
        body: 'Hubo un problema al mostrar el documento.',
      ),
  };
}
