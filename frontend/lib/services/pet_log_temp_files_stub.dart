Future<String> writeTemp(List<int> bytes, String extension, int index) async =>
    throw UnsupportedError('Temporary files are only used on mobile.');
Future<bool> deleteTemp(String path) async => true;
