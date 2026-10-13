import 'dart:io';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createPreview(String path) async =>
    VideoPlayerController.file(File(path));
