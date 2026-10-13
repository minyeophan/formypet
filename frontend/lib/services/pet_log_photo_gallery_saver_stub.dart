import 'dart:typed_data';

Future<void> savePetLogPhotoToGallery(
  Uint8List bytes,
  String fileName, {
  String? contentType,
}) async {
  throw UnsupportedError(
    'Photo gallery saving is not supported on this platform.',
  );
}
