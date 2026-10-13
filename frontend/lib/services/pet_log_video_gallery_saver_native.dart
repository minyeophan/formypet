import 'package:gal/gal.dart';

Future<void> savePetLogVideo(String path) async =>
    Gal.putVideo(path, album: '포마펫');
