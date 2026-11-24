/// Convierte un URI de origen (`content://…` o `file://…`) en una ubicación
/// legible para mostrar al usuario, o `null` si no se conoce el origen.
String? describeSource(String? uri) {
  if (uri == null) return null;
  final trimmed = uri.trim();
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return trimmed;

  if (parsed.scheme == 'file') {
    try {
      return parsed.toFilePath();
    } on UnsupportedError {
      return parsed.path.isNotEmpty ? Uri.decodeFull(parsed.path) : trimmed;
    }
  }

  if (parsed.scheme == 'content') {
    return _describeContentUri(parsed);
  }

  return trimmed;
}

String _describeContentUri(Uri uri) {
  final rawAuthority = uri.authority;
  final authority = rawAuthority.toLowerCase();

  if (authority == 'com.android.externalstorage.documents') {
    final externalPath = _extractExternalStoragePath(uri.pathSegments);
    if (externalPath != null) return externalPath;
    return 'Almacenamiento del teléfono';
  }

  if (authority == 'com.android.providers.downloads.documents') {
    return 'Descargas';
  }

  if (authority.contains('whatsapp')) {
    return 'Compartido desde WhatsApp';
  }

  if (authority.contains('com.google.android.gm')) {
    return 'Adjunto de Gmail';
  }

  if (authority.contains('com.google.android.apps.docs')) {
    return 'Google Drive';
  }

  if (authority == 'media' ||
      authority == 'com.android.providers.media.documents') {
    return 'Almacenamiento del teléfono';
  }

  return rawAuthority.isNotEmpty
      ? 'Compartido desde otra app ($rawAuthority)'
      : 'Compartido desde otra app';
}

String? _extractExternalStoragePath(List<String> segments) {
  final docIdx = segments.indexOf('document');
  final treeIdx = segments.indexOf('tree');
  final startIdx =
      docIdx != -1 ? docIdx + 1 : (treeIdx != -1 ? treeIdx + 1 : -1);
  if (startIdx == -1 || startIdx >= segments.length) return null;

  final docId = segments.sublist(startIdx).join('/');
  final colon = docId.indexOf(':');
  if (colon <= 0) return null;

  final volume = docId.substring(0, colon);
  final relPath = docId.substring(colon + 1).replaceFirst(RegExp(r'^/+'), '');
  final root = volume.toLowerCase() == 'primary'
      ? '/storage/emulated/0'
      : '/storage/$volume';
  return relPath.isEmpty ? root : '$root/$relPath';
}
