import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<void> savePetLogPhotoToGallery(
  Uint8List bytes,
  String fileName, {
  String? contentType,
}) async {
  final extensionSeparator = fileName.lastIndexOf('.');
  final name = extensionSeparator > 0
      ? fileName.substring(0, extensionSeparator)
      : fileName;
  await Gal.putImageBytes(bytes, album: '포마펫', name: name);
}
