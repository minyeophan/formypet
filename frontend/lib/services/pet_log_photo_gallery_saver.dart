import 'dart:typed_data';

import 'pet_log_photo_gallery_saver_stub.dart'
    if (dart.library.html) 'pet_log_photo_gallery_saver_web.dart'
    if (dart.library.io) 'pet_log_photo_gallery_saver_native.dart'
    as platform;

Future<void> savePetLogPhotoToGallery(
  Uint8List bytes,
  String fileName, {
  String? contentType,
}) => platform.savePetLogPhotoToGallery(
  bytes,
  fileName,
  contentType: contentType,
);
