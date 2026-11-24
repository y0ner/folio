import 'package:flutter/foundation.dart';

/// Estado del visor.
enum ViewerStatus { loading, ready, failed }

/// Por qué no se pudo mostrar un documento.
enum ViewerFailureKind {
  /// Protegido con contraseña.
  encrypted,

  /// Dañado o con un formato que no corresponde a su extensión.
  corrupt,

  /// Formato no admitido (p. ej. .doc antiguo).
  unsupported,

  /// El archivo ya no existe en el almacenamiento.
  missing,

  /// Falló el motor de renderizado.
  engine,
}

@immutable
class ViewerFailure {
  const ViewerFailure(this.kind, {this.detail});
  final ViewerFailureKind kind;

  /// Detalle técnico para el registro (no se muestra al usuario).
  final String? detail;
}

/// Contrato entre la pantalla del visor (barras, indicador, errores) y el
/// cuerpo que dibuja cada tipo de documento (PDF, Word, Excel, PowerPoint).
///
/// - El **cuerpo** informa: [markReady], [setPage], [fail], y registra sus
///   acciones con [attach].
/// - La **pantalla** lee el estado y pide navegar con [goToPage] /
///   [selectSection].
class ViewerController extends ChangeNotifier {
  ViewerStatus _status = ViewerStatus.loading;
  ViewerFailure? _failure;
  int _pageCount = 0;
  int _currentPage = 1;
  List<String> _sections = const [];
  int _currentSection = 0;

  void Function(int page)? _onGoToPage;
  void Function(int section)? _onSelectSection;

  ViewerStatus get status => _status;
  ViewerFailure? get failure => _failure;

  /// Páginas o diapositivas; 0 si el formato no pagina (p. ej. Excel).
  int get pageCount => _pageCount;

  /// Página visible, empezando en 1.
  int get currentPage => _currentPage;

  /// Secciones navegables (nombres de hojas en Excel); vacío si no aplica.
  List<String> get sections => _sections;
  int get currentSection => _currentSection;

  /// El cuerpo registra cómo navegar. Llamar de nuevo reemplaza lo anterior.
  void attach({
    void Function(int page)? onGoToPage,
    void Function(int section)? onSelectSection,
  }) {
    _onGoToPage = onGoToPage;
    _onSelectSection = onSelectSection;
  }

  void markReady({int pageCount = 0, List<String> sections = const []}) {
    _status = ViewerStatus.ready;
    _failure = null;
    _pageCount = pageCount;
    _currentPage = pageCount > 0 ? 1 : 0;
    _sections = List.unmodifiable(sections);
    _currentSection = 0;
    notifyListeners();
  }

  void setPage(int page) {
    if (page == _currentPage || page < 1 || page > _pageCount) return;
    _currentPage = page;
    notifyListeners();
  }

  void fail(ViewerFailure failure) {
    _status = ViewerStatus.failed;
    _failure = failure;
    notifyListeners();
  }

  void goToPage(int page) {
    if (page < 1 || page > _pageCount) return;
    _onGoToPage?.call(page);
  }

  void selectSection(int index) {
    if (index < 0 || index >= _sections.length) return;
    _currentSection = index;
    notifyListeners();
    _onSelectSection?.call(index);
  }
}
