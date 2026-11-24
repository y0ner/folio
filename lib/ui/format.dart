const _months = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formatea un tamaño en bytes en español (`850 B`, `12 KB`, `3,4 MB`, `1,2 GB`).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  if (bytes < gb) {
    return '${(bytes / mb).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
}

/// Formatea la fecha de última apertura en relación con [now].
String formatOpenedAt(DateTime t, {required DateTime now}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(t.year, t.month, t.day);
  final diffDays = today.difference(day).inDays;

  if (diffDays == 0) {
    return 'Hoy, ${_twoDigits(t.hour)}:${_twoDigits(t.minute)}';
  }
  if (diffDays == 1) {
    return 'Ayer, ${_twoDigits(t.hour)}:${_twoDigits(t.minute)}';
  }

  final month = _months[t.month - 1];
  if (t.year == now.year) {
    return '${t.day} $month';
  }
  return '${t.day} $month ${t.year}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
