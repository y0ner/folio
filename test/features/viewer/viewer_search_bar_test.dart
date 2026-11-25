import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/core/theme/folio_theme.dart';
import 'package:folio/features/viewer/viewer_controller.dart';
import 'package:folio/features/viewer/widgets/viewer_search_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeViewerSearch extends ChangeNotifier implements ViewerSearch {
  _FakeViewerSearch({
    this.query = '',
    this.isSearching = false,
    this.matchCount = 0,
    this.currentIndex = -1,
  });

  @override
  String query;

  @override
  bool isSearching;

  @override
  int matchCount;

  @override
  int currentIndex;

  final List<String> searchCalls = [];
  int nextCalls = 0;
  int previousCalls = 0;
  int clearCalls = 0;

  void updateState({
    String? query,
    bool? isSearching,
    int? matchCount,
    int? currentIndex,
  }) {
    if (query != null) this.query = query;
    if (isSearching != null) this.isSearching = isSearching;
    if (matchCount != null) this.matchCount = matchCount;
    if (currentIndex != null) this.currentIndex = currentIndex;
    notifyListeners();
  }

  @override
  void search(String query) {
    searchCalls.add(query);
    this.query = query;
    notifyListeners();
  }

  @override
  void next() {
    nextCalls++;
    if (matchCount > 0) {
      currentIndex = (currentIndex + 1) % matchCount;
      notifyListeners();
    }
  }

  @override
  void previous() {
    previousCalls++;
    if (matchCount > 0) {
      currentIndex = currentIndex <= 0 ? matchCount - 1 : currentIndex - 1;
      notifyListeners();
    }
  }

  @override
  void clear() {
    clearCalls++;
    query = '';
    isSearching = false;
    matchCount = 0;
    currentIndex = -1;
    notifyListeners();
  }
}

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: FolioTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('muestra "3 de 12" y navega con next y previous', (tester) async {
    final search = _FakeViewerSearch(
      query: 'folio',
      matchCount: 12,
      currentIndex: 2,
    );
    addTearDown(search.dispose);

    await tester.pumpWidget(
      wrap(ViewerSearchBar(search: search, onClose: () {})),
    );

    expect(find.text('3 de 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente resultado'));
    await tester.pump();
    expect(search.nextCalls, 1);
    expect(find.text('4 de 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Resultado anterior'));
    await tester.pump();
    expect(search.previousCalls, 1);
    expect(find.text('3 de 12'), findsOneWidget);
  });

  testWidgets('muestra "Sin resultados" y desactiva botones sin coincidencias',
      (tester) async {
    final search = _FakeViewerSearch(
      query: 'inexistente',
      matchCount: 0,
      currentIndex: -1,
    );
    addTearDown(search.dispose);

    await tester.pumpWidget(
      wrap(ViewerSearchBar(search: search, onClose: () {})),
    );

    expect(find.text('Sin resultados'), findsOneWidget);

    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, LucideIcons.chevronUp),
    );
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, LucideIcons.chevronDown),
    );
    expect(prevButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('muestra indicador de 16 dp mientras busca sin resultados aún',
      (tester) async {
    final search = _FakeViewerSearch(
      query: 'folio',
      isSearching: true,
      matchCount: 0,
    );
    addTearDown(search.dispose);

    await tester.pumpWidget(
      wrap(ViewerSearchBar(search: search, onClose: () {})),
    );

    final indicator = find.byType(CircularProgressIndicator);
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator), const Size(16, 16));
  });

  testWidgets('espera 350 ms al escribir y Enter llama next', (tester) async {
    final search = _FakeViewerSearch();
    addTearDown(search.dispose);

    await tester.pumpWidget(
      wrap(ViewerSearchBar(search: search, onClose: () {})),
    );

    await tester.enterText(find.byType(TextField), 'contrato');
    await tester.pump(const Duration(milliseconds: 200));
    expect(search.searchCalls, isEmpty);

    await tester.pump(const Duration(milliseconds: 150));
    expect(search.searchCalls, ['contrato']);

    search.updateState(matchCount: 5, currentIndex: 0);
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(search.nextCalls, 1);
  });

  testWidgets('cerrar llama clear y onClose', (tester) async {
    final search = _FakeViewerSearch(
      query: 'folio',
      matchCount: 3,
      currentIndex: 0,
    );
    addTearDown(search.dispose);
    var closed = false;

    await tester.pumpWidget(
      wrap(ViewerSearchBar(search: search, onClose: () => closed = true)),
    );

    await tester.tap(find.byTooltip('Cerrar búsqueda'));
    await tester.pump();

    expect(search.clearCalls, 1);
    expect(closed, isTrue);
  });
}
