import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:frontend/services/pet_log_book_image_composer.dart';

Uint8List _png(int width, int height, int red, int green, int blue) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, green, blue));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('PetLogBookImageComposer', () {
    test('composes photos top to bottom and preserves proportions', () async {
      final bytes = await PetLogBookImageComposer.compose([
        _png(2, 1, 255, 0, 0),
        _png(1, 2, 0, 0, 255),
      ]);
      final result = img.decodeImage(bytes)!;

      expect(result.width, 2);
      expect(result.height, 3);
      expect(result.getPixel(0, 0).r, greaterThan(220));
      expect(result.getPixel(0, 1).b, greaterThan(220));
      expect(result.getPixel(1, 1).r, greaterThan(220));
      expect(result.getPixel(0, 2).b, greaterThan(220));
    });

    test(
      'reduces the output canvas when its pixel budget is exceeded',
      () async {
        final bytes = await PetLogBookImageComposer.compose([
          _png(4, 4, 255, 0, 0),
          _png(4, 4, 0, 0, 255),
        ], maxOutputPixels: 16);

        final result = img.decodeImage(bytes)!;
        expect(result.width, 2);
        expect(result.height, 4);
        expect(result.width * result.height, lessThanOrEqualTo(16));
        expect(result.getPixel(0, 0).r, greaterThan(220));
        expect(result.getPixel(0, 3).b, greaterThan(220));
      },
    );

    test('rejects an empty selection', () async {
      expect(
        () => PetLogBookImageComposer.compose(const []),
        throwsArgumentError,
      );
    });

    test('rejects corrupt photo bytes', () async {
      expect(
        () => PetLogBookImageComposer.compose([
          Uint8List.fromList([1, 2, 3]),
        ]),
        throwsFormatException,
      );
    });

    test(
      'normalizes a selected photo to JPEG for native video encoding',
      () async {
        final normalized = await PetLogBookImageComposer.normalizePhoto(
          _png(3, 2, 35, 120, 220),
        );
        final decoded = img.decodeImage(normalized)!;
        expect(normalized[0], 0xff);
        expect(normalized[1], 0xd8);
        expect(decoded.width, 3);
        expect(decoded.height, 2);
        expect(decoded.getPixel(1, 1).b, greaterThan(190));
      },
    );
  });
}
