import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> writeTemp(List<int> bytes, String extension, int index) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/pet-log-${DateTime.now().microsecondsSinceEpoch}-$index.$extension',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<bool> deleteTemp(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
    return true;
  } catch (_) {}
  return false;
}
