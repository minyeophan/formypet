import 'package:flutter/material.dart';

sealed class AppVisualSource {
  const AppVisualSource();
}

final class MaterialVisualSource extends AppVisualSource {
  final IconData icon;

  const MaterialVisualSource(this.icon);
}

final class EmojiVisualSource extends AppVisualSource {
  final String value;

  const EmojiVisualSource(this.value) : assert(value.length > 0);
}

final class SvgAssetVisualSource extends AppVisualSource {
  final String path;
  final bool tintable;
  final Rect? drawingBounds;
  final double? strokeWidth;

  const SvgAssetVisualSource(this.path, {this.tintable = false})
    : drawingBounds = null,
      strokeWidth = null,
      assert(path.length > 0);

  /// Approved exports use a 64px canvas with a centered 48px drawing area.
  /// The asset remains untouched; only its app viewport is normalized.
  const SvgAssetVisualSource.figma(
    this.path, {
    this.tintable = false,
    this.strokeWidth,
  }) : drawingBounds = const Rect.fromLTWH(8, 8, 48, 48),
       assert(path.length > 0),
       assert(strokeWidth == null || strokeWidth > 0);
}

final class RasterAssetVisualSource extends AppVisualSource {
  final String path;

  const RasterAssetVisualSource(this.path) : assert(path.length > 0);
}

sealed class AppVisualFallback {
  const AppVisualFallback();

  const factory AppVisualFallback.material(IconData icon) =
      MaterialVisualFallback;
  const factory AppVisualFallback.emoji(String value) = EmojiVisualFallback;
}

final class MaterialVisualFallback extends AppVisualFallback {
  final IconData icon;

  const MaterialVisualFallback(this.icon);
}

final class EmojiVisualFallback extends AppVisualFallback {
  final String value;

  const EmojiVisualFallback(this.value) : assert(value.length > 0);
}

class AppVisualSpec {
  final AppVisualSource source;
  final AppVisualFallback? fallback;

  const AppVisualSpec({required this.source, this.fallback})
    : assert(
        source is MaterialVisualSource ||
            source is EmojiVisualSource ||
            source is SvgAssetVisualSource ||
            fallback != null,
      );
}
