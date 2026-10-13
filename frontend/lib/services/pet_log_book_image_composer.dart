import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class PetLogBookImageComposer {
  const PetLogBookImageComposer._();

  static const int _maxOutputWidth = 1080;
  static const int _maxOutputPixels = 12 * 1000 * 1000;

  static Future<Uint8List> compose(
    List<Uint8List> photoBytes, {
    int maxOutputPixels = _maxOutputPixels,
  }) {
    if (photoBytes.isEmpty) {
      throw ArgumentError.value(photoBytes, 'photoBytes', 'Must not be empty.');
    }
    if (maxOutputPixels < 1) {
      throw ArgumentError.value(maxOutputPixels, 'maxOutputPixels');
    }
    return compute(
      _composeInBackground,
      _CompositionInput(photoBytes, maxOutputPixels),
      debugLabel: 'pet-log-image',
    );
  }

  static Future<Uint8List> normalizePhoto(Uint8List photoBytes) => compute(
    _normalizeInBackground,
    photoBytes,
    debugLabel: 'pet-log-video-photo',
  );

  static Uint8List _normalizeInBackground(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('A selected photo could not be decoded.');
    }
    return Uint8List.fromList(
      img.encodeJpg(img.bakeOrientation(decoded), quality: 92),
    );
  }

  static Uint8List _composeInBackground(_CompositionInput input) {
    final sizes = <(int, int)>[];
    for (final bytes in input.photoBytes) {
      img.Image? decoded;
      try {
        decoded = img.decodeImage(bytes);
      } catch (_) {
        throw const FormatException('A selected photo could not be decoded.');
      }
      if (decoded == null) {
        throw const FormatException('A selected photo could not be decoded.');
      }
      final oriented = img.bakeOrientation(decoded);
      sizes.add((oriented.width, oriented.height));
    }

    final baseWidth = sizes
        .map((size) => size.$1)
        .reduce((a, b) => a > b ? a : b);
    var outputWidth = baseWidth > _maxOutputWidth ? _maxOutputWidth : baseWidth;
    int scaledHeight(int width) => sizes.fold<int>(
      0,
      (sum, size) => sum + _scaledDimension(size.$2, size.$1, width),
    );
    while (outputWidth > 1 &&
        outputWidth * scaledHeight(outputWidth) > input.maxOutputPixels) {
      outputWidth--;
    }
    final outputHeight = scaledHeight(outputWidth);
    if (outputWidth * outputHeight > input.maxOutputPixels) {
      throw const FormatException(
        'The selected photos exceed the supported output size.',
      );
    }

    final canvas = img.Image(
      width: outputWidth,
      height: outputHeight,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var top = 0;
    for (var index = 0; index < input.photoBytes.length; index++) {
      final decoded = img.decodeImage(input.photoBytes[index]);
      if (decoded == null) {
        throw const FormatException('A selected photo could not be decoded.');
      }
      final photo = img.bakeOrientation(decoded);
      final row = photo.width > outputWidth
          ? img.copyResize(
              photo,
              width: outputWidth,
              interpolation: img.Interpolation.average,
            )
          : photo;
      final left = (outputWidth - row.width) ~/ 2;
      img.compositeImage(canvas, row, dstX: left, dstY: top);
      top += row.height;
    }

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  static int _scaledDimension(int sourceHeight, int sourceWidth, int width) =>
      sourceWidth <= width
      ? sourceHeight
      : (sourceHeight * width / sourceWidth).round().clamp(1, sourceHeight);
}

class _CompositionInput {
  const _CompositionInput(this.photoBytes, this.maxOutputPixels);

  final List<Uint8List> photoBytes;
  final int maxOutputPixels;
}
