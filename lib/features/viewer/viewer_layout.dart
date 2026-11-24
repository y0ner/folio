import 'package:flutter/material.dart';

/// Medidas que comparten la pantalla del visor y los cuerpos.
///
/// Las barras flotan sobre el documento (modo inmersivo), así que cada cuerpo
/// deja un margen arriba y abajo para que el **inicio** y el **final** del
/// documento se vean sin quedar tapados por las barras.
abstract final class ViewerLayout {
  /// Alto de la barra superior (sin la barra de estado) + su borde de 1 px.
  static const double topBarHeight = kToolbarHeight + 1;

  /// Espacio inferior reservado para el indicador de página o las pestañas.
  static const double bottomReserve = 72;

  /// Márgenes del contenido según la pantalla actual.
  static EdgeInsets contentInsets(BuildContext context) {
    final view = MediaQuery.viewPaddingOf(context);
    return EdgeInsets.only(
      top: view.top + topBarHeight,
      bottom: view.bottom + bottomReserve,
    );
  }
}
