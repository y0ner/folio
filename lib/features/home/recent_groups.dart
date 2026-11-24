import 'package:flutter/foundation.dart';

import '../../core/files/doc_kind.dart';
import '../../core/files/document_ref.dart';

/// Grupo cronológico de documentos recientes.
@immutable
class RecentGroup {
  const RecentGroup({required this.label, required this.items});

  final String label;
  final List<DocumentRef> items;
}

/// Agrupa [items] en `Hoy`, `Esta semana` (últimos 7 días sin hoy) y
/// `Anteriores`, omitiendo grupos vacíos y conservando el orden de entrada.
List<RecentGroup> groupRecents(
  List<DocumentRef> items, {
  required DateTime now,
}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final hoy = <DocumentRef>[];
  final estaSemana = <DocumentRef>[];
  final anteriores = <DocumentRef>[];

  for (final item in items) {
    final day = DateTime.utc(
      item.openedAt.year,
      item.openedAt.month,
      item.openedAt.day,
    );
    final diffDays = today.difference(day).inDays;

    if (diffDays == 0) {
      hoy.add(item);
    } else if (diffDays >= 1 && diffDays <= 7) {
      estaSemana.add(item);
    } else {
      anteriores.add(item);
    }
  }

  return [
    if (hoy.isNotEmpty) RecentGroup(label: 'Hoy', items: hoy),
    if (estaSemana.isNotEmpty)
      RecentGroup(label: 'Esta semana', items: estaSemana),
    if (anteriores.isNotEmpty)
      RecentGroup(label: 'Anteriores', items: anteriores),
  ];
}

/// Filtra [items] por tipo [kind] y por coincidencia en el nombre con [query]
/// sin distinguir mayúsculas ni tildes.
List<DocumentRef> filterRecents(
  List<DocumentRef> items, {
  String query = '',
  DocKind? kind,
}) {
  final normalizedQuery = _normalize(query.trim());
  return [
    for (final item in items)
      if ((kind == null || item.kind == kind) &&
          (normalizedQuery.isEmpty ||
              _normalize(item.name).contains(normalizedQuery)))
        item,
  ];
}

String _normalize(String input) {
  final lower = input
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  const from = 'áàäâãåéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    final idx = from.indexOf(ch);
    buffer.write(idx >= 0 ? to[idx] : ch);
  }
  return buffer.toString();
}
