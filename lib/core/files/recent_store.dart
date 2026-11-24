import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_ref.dart';

/// Lista de documentos abiertos recientemente (el más reciente primero).
class RecentStore extends ChangeNotifier {
  RecentStore(this._prefs) {
    _items = _load();
  }

  static const String prefsKey = 'recents.v1';
  static const int maxItems = 40;

  final SharedPreferencesWithCache _prefs;
  late List<DocumentRef> _items;

  List<DocumentRef> get items => List.unmodifiable(_items);

  /// Agrega o sube al primer lugar. Devuelve los que salieron por exceder
  /// [maxItems], para que quien llama borre sus copias locales.
  Future<List<DocumentRef>> add(DocumentRef ref) async {
    _items = [ref, ..._items.where((e) => e != ref)];
    final evicted = <DocumentRef>[];
    if (_items.length > maxItems) {
      evicted.addAll(_items.sublist(maxItems));
      _items = _items.sublist(0, maxItems);
    }
    await _save();
    return evicted;
  }

  Future<void> remove(DocumentRef ref) async {
    _items = _items.where((e) => e != ref).toList();
    await _save();
  }

  Future<void> clear() async {
    _items = [];
    await _save();
  }

  List<DocumentRef> _load() {
    final raw = _prefs.getStringList(prefsKey) ?? const [];
    final out = <DocumentRef>[];
    for (final s in raw) {
      try {
        final ref = DocumentRef.fromJson(jsonDecode(s) as Map<String, dynamic>);
        if (ref != null) out.add(ref);
      } on FormatException catch (e) {
        debugPrint('RecentStore: entrada inválida descartada ($e)');
      }
    }
    return out;
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setStringList(
      prefsKey,
      [for (final e in _items) jsonEncode(e.toJson())],
    );
  }
}
