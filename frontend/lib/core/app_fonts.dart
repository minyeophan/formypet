import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled variable font: first launch must not depend on a font CDN.
abstract final class AppFonts {
  static const family = 'NotoSansKR';
  static bool _licensesRegistered = false;

  static void registerLicenses() {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'Noto Sans KR',
        'Plus Jakarta Sans',
      ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    });
  }
}
