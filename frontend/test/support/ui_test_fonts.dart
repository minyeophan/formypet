import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;

/// Local fixture for interaction/pixel tests, not Korean text layout approval.
Future<void> installUiTestFonts() async {
  final fixture = ByteData.sublistView(
    File('assets/fonts/PlusJakartaSans-Variable.ttf').readAsBytesSync(),
  );
  GoogleFonts.config.allowRuntimeFetching = false;
  fonts.assetManifest = _FontManifest();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final asset = const StringCodec().decodeMessage(message);
    if (asset != null && asset.startsWith('ui-test-font/')) return fixture;
    final file = File('build/unit_test_assets/$asset');
    return file.existsSync()
        ? ByteData.sublistView(file.readAsBytesSync())
        : null;
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    fonts.assetManifest = null;
    fonts.clearCache();
  });
}

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    'Thin',
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ].map((weight) => 'ui-test-font/NotoSansKR-$weight.ttf').toList();

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
