import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:frontend/services/photo_preparation.dart';

void main() {
  test(
    'async preparation preserves bytes and upload filename through XFile',
    () async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 1)),
      );
      final prepared = await preparePhoto(
        XFile.fromData(bytes, path: 'selected.png', name: 'selected.png'),
      );
      expect(prepared.bytes, bytes);
      expect(prepared.asFile().name, 'selected.png');
      expect(await prepared.asFile().readAsBytes(), bytes);
      expect(prepared.mimeType, 'image/png');
    },
  );
  test('oversize input is rejected before loading file bytes', () async {
    final file = _OversizePhoto();
    await expectLater(
      preparePhoto(file),
      throwsA(isA<PhotoPreparationException>()),
    );
    expect(file.read, isFalse);
  });
  test('small PNG keeps exact bytes and transparency', () {
    final source = img.Image(width: 10, height: 5, numChannels: 4);
    final bytes = Uint8List.fromList(img.encodePng(source));
    final result = preparePhotoBytes(bytes, 'photo.png');
    expect(result.bytes, bytes);
    expect(img.decodePng(result.bytes)!.getPixel(0, 0).a, 0);
  });
  test('large portrait PNG preserves ratio and alpha without cropping', () {
    final source = img.Image(width: 1000, height: 2000, numChannels: 4);
    final result = preparePhotoBytes(
      Uint8List.fromList(img.encodePng(source)),
      'photo.png',
    );
    final decoded = img.decodePng(result.bytes)!;
    expect(decoded.width, 800);
    expect(decoded.height, 1600);
    expect(decoded.getPixel(0, 0).a, 0);
  });
  test('mismatched filename and corrupt input are rejected', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    expect(
      () => preparePhotoBytes(png, 'photo.jpg'),
      throwsA(
        isA<PhotoPreparationException>().having(
          (error) => error.message,
          'message',
          contains('확장자'),
        ),
      ),
    );
    expect(
      () => preparePhotoBytes(Uint8List.fromList([1, 2, 3]), 'photo.png'),
      throwsA(
        isA<PhotoPreparationException>().having(
          (error) => error.message,
          'message',
          contains('손상'),
        ),
      ),
    );
  });

  test(
    '1600px and exactly 5MiB retain original bytes, one byte over recompresses',
    () {
      final jpeg = img.encodeJpg(img.Image(width: 1600, height: 1));
      final exact = Uint8List(maxPhotoBytes)..setRange(0, jpeg.length, jpeg);
      expect(preparePhotoBytes(exact, 'edge.jpg').bytes, exact);
      final oversized = Uint8List(maxPhotoBytes + 1)
        ..setRange(0, jpeg.length, jpeg);
      expect(
        preparePhotoBytes(oversized, 'edge.jpg').bytes.length,
        lessThan(maxPhotoBytes),
      );
    },
  );
  test('panoramas keep full aspect ratio', () {
    final result = preparePhotoBytes(
      Uint8List.fromList(img.encodePng(img.Image(width: 4000, height: 100))),
      'wide.png',
    );
    final decoded = img.decodePng(result.bytes)!;
    expect((decoded.width, decoded.height), (1600, 40));
  });
  test('EXIF rotated JPEG is oriented before resize', () {
    final source = img.Image(width: 2000, height: 100);
    source.exif.imageIfd.orientation = 6;
    final result = preparePhotoBytes(
      Uint8List.fromList(img.encodeJpg(source)),
      'rotated.jpg',
    );
    final decoded = img.decodeJpg(result.bytes)!;
    expect((decoded.width, decoded.height), (80, 1600));
    expect(decoded.exif.imageIfd.orientation, anyOf(isNull, 1));
  });
  test('transparent WebP keeps transparency when resized', () {
    final source = img.Image(width: 1602, height: 4, numChannels: 4);
    final result = preparePhotoBytes(
      Uint8List.fromList(img.encodeWebP(source)),
      'alpha.webp',
    );
    final decoded = img.decodeWebP(result.bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.getPixel(0, 0).a, 0);
    expect(result.mimeType, 'image/webp');
  });
  test('animation requiring resize is rejected without flattening', () {
    final source = img.Image(width: 1601, height: 2, numChannels: 4);
    source.addFrame(img.Image(width: 1601, height: 2, numChannels: 4));
    final bytes = Uint8List.fromList(img.encodePng(source));
    expect(img.PngDecoder().startDecode(bytes)!.numFrames, 2);
    expect(
      () => preparePhotoBytes(bytes, 'animated.png'),
      throwsA(isA<PhotoPreparationException>()),
    );
  });
  test('unsupported format asks for another photo', () {
    expect(
      () => preparePhotoBytes(Uint8List(0), 'photo.heic'),
      throwsA(isA<PhotoPreparationException>()),
    );
  });

  test('small animation is preserved byte for byte', () {
    final source = img.Image(width: 4, height: 2, numChannels: 4);
    source.addFrame(img.Image(width: 4, height: 2, numChannels: 4));
    final bytes = Uint8List.fromList(img.encodePng(source));
    expect(preparePhotoBytes(bytes, 'animated.png').bytes, bytes);
  });
}

class _OversizePhoto extends XFile {
  _OversizePhoto() : super('oversize.png');
  bool read = false;
  @override
  Future<int> length() async => 40 * 1024 * 1024 + 1;
  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    throw StateError('Must reject before reading');
  }
}
