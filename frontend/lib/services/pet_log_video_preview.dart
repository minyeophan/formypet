import 'package:video_player/video_player.dart';
import 'pet_log_video_preview_stub.dart'
    if (dart.library.io) 'pet_log_video_preview_native.dart'
    as platform;

Future<VideoPlayerController> createPetLogVideoPreview(String path) =>
    platform.createPreview(path);
