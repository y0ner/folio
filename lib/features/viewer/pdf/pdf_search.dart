import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../viewer_controller.dart';

const _diacriticToBase = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

const _accentGroups = <String, String>{
  'a': '[aAáÁàÀäÄâÂãÃåÅ]',
  'e': '[eEéÉèÈëËêÊ]',
  'i': '[iIíÍìÌïÏîÎ]',
  'o': '[oOóÓòÒöÖôÔõÕ]',
  'u': '[uUúÚùÙüÜûÛ]',
  'n': '[nNñÑ]',
  'c': '[cCçÇ]',
};

final _combiningMarks = RegExp(r'[\u0300-\u036f]');

/// Construye un [Pattern] que busca [query] sin distinguir mayúsculas ni tildes.
Pattern buildPdfSearchPattern(String query) {
  if (query.isEmpty) return '';
  final stripped = query.replaceAll(_combiningMarks, '');
  if (stripped.isEmpty) {
    return RegExp(RegExp.escape(query), caseSensitive: false);
  }
  final buffer = StringBuffer();
  for (final rune in stripped.runes) {
    final ch = String.fromCharCode(rune);
    final base = _diacriticToBase[ch.toLowerCase()];
    final group = base != null ? _accentGroups[base] : null;
    if (group != null) {
      buffer.write(group);
      buffer.write(r'[\u0300-\u036f]*');
    } else {
      buffer.write(RegExp.escape(ch));
    }
  }
  return RegExp(buffer.toString(), caseSensitive: false);
}

/// Adaptador de [PdfTextSearcher] al contrato [ViewerSearch] de Folio.
class PdfViewerSearch extends ChangeNotifier implements ViewerSearch {
  PdfViewerSearch(PdfViewerController controller)
      : _searcher = PdfTextSearcher(controller) {
    _searcher.addListener(_onSearcherChanged);
  }

  final PdfTextSearcher _searcher;
  String _query = '';
  bool _disposed = false;

  @override
  String get query => _query;

  @override
  bool get isSearching => !_disposed && _searcher.isSearching;

  @override
  int get matchCount => _searcher.matches.length;

  @override
  int get currentIndex {
    final index = _searcher.currentIndex;
    if (index == null || index < 0 || index >= _searcher.matches.length) {
      return -1;
    }
    return index;
  }

  @override
  void search(String query) {
    if (_disposed) return;
    if (query.isEmpty) {
      clear();
      return;
    }
    if (query == _query) return;
    _query = query;
    _searcher.startTextSearch(
      buildPdfSearchPattern(query),
      goToFirstMatch: true,
      searchImmediately: true,
    );
    notifyListeners();
  }

  @override
  void next() {
    if (_disposed) return;
    final count = _searcher.matches.length;
    if (count == 0) return;
    final current = currentIndex;
    final nextIndex = current < 0 || current + 1 >= count ? 0 : current + 1;
    unawaited(_searcher.goToMatchOfIndex(nextIndex));
    notifyListeners();
  }

  @override
  void previous() {
    if (_disposed) return;
    final count = _searcher.matches.length;
    if (count == 0) return;
    final current = currentIndex;
    final prevIndex = current <= 0 ? count - 1 : current - 1;
    unawaited(_searcher.goToMatchOfIndex(prevIndex));
    notifyListeners();
  }

  @override
  void clear() {
    if (_disposed) return;
    if (_query.isEmpty &&
        _searcher.matches.isEmpty &&
        !_searcher.isSearching) {
      return;
    }
    _query = '';
    _searcher.resetTextSearch();
  }

  /// Dibuja el resaltado de coincidencias sobre [page].
  void paintMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    if (_disposed) return;
    _searcher.pageTextMatchPaintCallback(canvas, pageRect, page);
  }

  void _onSearcherChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _searcher.removeListener(_onSearcherChanged);
    _searcher.dispose();
    super.dispose();
  }
}
