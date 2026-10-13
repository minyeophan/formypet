import 'pet_log_video_gallery_saver_stub.dart'
    if (dart.library.io) 'pet_log_video_gallery_saver_native.dart'
    as platform;

Future<void> savePetLogVideoToGallery(String path) =>
    platform.savePetLogVideo(path);
