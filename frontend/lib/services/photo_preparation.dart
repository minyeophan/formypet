import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const maxPhotoBytes = 5 * 1024 * 1024;

class PhotoPreparationException implements Exception {
  final String message;
  const PhotoPreparationException(this.message);
  @override
  String toString() => message;
}

class PreparedPhoto {
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  const PreparedPhoto(this.bytes, this.filename, this.mimeType);
  XFile asFile() =>
      XFile.fromData(bytes, name: filename, path: filename, mimeType: mimeType);
}

Future<PreparedPhoto> preparePhoto(XFile file) async {
  if (await file.length() > 40 * 1024 * 1024) {
    throw const PhotoPreparationException(
      '사진이 너무 커서 처리할 수 없어요. 40MB 이하 사진을 선택해 주세요.',
    );
  }
  final bytes = await file.readAsBytes();
  return compute(_prepare, (bytes, file.name));
}

PreparedPhoto _prepare((Uint8List, String) input) =>
    preparePhotoBytes(input.$1, input.$2);

PreparedPhoto preparePhotoBytes(Uint8List bytes, String filename) {
  try {
    return _preparePhotoBytes(bytes, filename);
  } on PhotoPreparationException {
    rethrow;
  } catch (_) {
    throw const PhotoPreparationException('사진 파일이 손상되어 읽을 수 없어요.');
  }
}

PreparedPhoto _preparePhotoBytes(Uint8List bytes, String filename) {
  final ext = filename.split('.').last.toLowerCase();
  if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
    throw const PhotoPreparationException(
      'JPG, PNG, WebP 사진만 지원해요. 다른 형식의 사진을 선택해 주세요.',
    );
  }
  final decoder = img.findDecoderForData(bytes);
  final format = decoder?.format;
  final expected = ext == 'png'
      ? img.ImageFormat.png
      : ext == 'webp'
      ? img.ImageFormat.webp
      : img.ImageFormat.jpg;
  if (decoder == null) {
    throw const PhotoPreparationException('사진 파일이 손상되어 읽을 수 없어요.');
  }
  if (format != expected) {
    throw const PhotoPreparationException(
      '사진의 실제 형식과 파일 확장자가 맞지 않아요. 다른 사진을 선택해 주세요.',
    );
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const PhotoPreparationException('사진 파일이 손상되어 읽을 수 없어요.');
  }
  if (info.width * info.height > 50000000) {
    throw const PhotoPreparationException(
      '사진을 처리할 수 없어요. 5천만 화소 이하 사진을 선택해 주세요.',
    );
  }
  final resize = info.width > 1600 || info.height > 1600;
  if (info.numFrames > 1 && (resize || bytes.length > maxPhotoBytes)) {
    throw const PhotoPreparationException(
      '움직이는 사진은 축소할 수 없어요. 1600px·5MB 이하 파일을 선택해 주세요.',
    );
  }
  img.Image? source;
  try {
    source = decoder.decodeFrame(0);
  } catch (_) {
    throw const PhotoPreparationException('사진 파일이 손상되어 읽을 수 없어요.');
  }
  if (source == null) {
    throw const PhotoPreparationException('사진 파일을 읽을 수 없어요.');
  }
  final mime = 'image/${expected == img.ImageFormat.jpg ? 'jpeg' : ext}';
  if (!resize && bytes.length <= maxPhotoBytes) {
    return PreparedPhoto(bytes, filename, mime);
  }
  source = img.bakeOrientation(source);
  if (resize) {
    source = source.width >= source.height
        ? img.copyResize(
            source,
            width: 1600,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            source,
            height: 1600,
            interpolation: img.Interpolation.average,
          );
  }
  for (final quality in [85, 75, 65]) {
    final output = expected == img.ImageFormat.png
        ? img.encodePng(source)
        : expected == img.ImageFormat.webp
        ? img.encodeWebP(source, lossless: false, quality: quality)
        : img.encodeJpg(source, quality: quality);
    if (output.length <= maxPhotoBytes) {
      return PreparedPhoto(Uint8List.fromList(output), filename, mime);
    }
    if (expected == img.ImageFormat.png) {
      break;
    }
  }
  throw const PhotoPreparationException('사진을 줄여도 5MB를 넘어요. 더 작은 사진을 선택해 주세요.');
}
