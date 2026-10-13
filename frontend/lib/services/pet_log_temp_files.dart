import 'pet_log_temp_files_stub.dart'
    if (dart.library.io) 'pet_log_temp_files_native.dart'
    as platform;

Future<String> writePetLogTempFile(
  List<int> bytes,
  String extension,
  int index,
) => platform.writeTemp(bytes, extension, index);
Future<bool> deletePetLogTempFile(String path) => platform.deleteTemp(path);
