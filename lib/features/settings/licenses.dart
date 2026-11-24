import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

const List<(String assetPath, List<String> packages)> _assetLicenses = [
  ('assets/licenses/Inter-OFL.txt', ['Inter']),
  ('assets/licenses/Carlito-OFL.txt', ['Carlito']),
  ('assets/licenses/Caladea-OFL.txt', ['Caladea']),
  ('assets/licenses/Liberation-OFL.txt', ['Liberation Fonts']),
  ('assets/licenses/docx-preview-LICENSE.txt', ['docx-preview']),
  ('assets/licenses/jszip-LICENSE.md', ['jszip']),
];

/// Registra en [LicenseRegistry] las licencias empaquetadas en `assets/licenses/`.
void registerAssetLicenses() {
  if (_registered) return;
  _registered = true;

  LicenseRegistry.addLicense(() async* {
    for (final (assetPath, packages) in _assetLicenses) {
      final text = await rootBundle.loadString(assetPath);
      yield LicenseEntryWithLineBreaks(packages, text);
    }
  });
}
