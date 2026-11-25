import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/viewer/viewer_controller.dart';

class _FakeSearch extends ChangeNotifier implements ViewerSearch {
  @override
  String query = '';
  @override
  bool isSearching = false;
  @override
  int matchCount = 0;
  @override
  int currentIndex = -1;
  @override
  void search(String q) => query = q;
  @override
  void next() {}
  @override
  void previous() {}
  @override
  void clear() => query = '';
}

void main() {
  test('markReady fija páginas y secciones', () {
    final c = ViewerController()..markReady(pageCount: 5, sections: ['A', 'B']);
    expect(c.status, ViewerStatus.ready);
    expect(c.currentPage, 1);
    expect(c.sections, ['A', 'B']);
  });

  test('setPage ignora páginas fuera de rango', () {
    final c = ViewerController()..markReady(pageCount: 3);
    c.setPage(9);
    expect(c.currentPage, 1);
    c.setPage(3);
    expect(c.currentPage, 3);
  });

  test('goToPage y selectSection llaman al cuerpo', () {
    final pages = <int>[];
    final sections = <int>[];
    final c = ViewerController()
      ..attach(onGoToPage: pages.add, onSelectSection: sections.add)
      ..markReady(pageCount: 4, sections: ['A', 'B']);
    c.goToPage(2);
    c.goToPage(0);
    c.selectSection(1);
    expect(pages, [2]);
    expect(sections, [1]);
    expect(c.currentSection, 1);
  });

  test('attach expone y reemplaza la búsqueda', () {
    final s = _FakeSearch();
    final c = ViewerController()..attach(search: s);
    expect(c.search, same(s));
    c.attach();
    expect(c.search, isNull);
  });
}
