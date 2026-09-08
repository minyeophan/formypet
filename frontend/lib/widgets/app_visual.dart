import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/visuals/app_visual_catalog.dart';
import '../core/visuals/app_visual_id.dart';
import '../core/visuals/app_visual_spec.dart';

class AppVisual extends StatelessWidget {
  final AppVisualId id;
  final AppVisualSpec? _spec;

  /// Displayed drawing size. Figma export padding is not counted in this size.
  final double size;
  final Color? color;
  final String? semanticLabel;

  const AppVisual({
    super.key,
    required this.id,
    required this.size,
    this.color,
    this.semanticLabel,
  }) : _spec = null;

  const AppVisual.fromSpec({
    super.key,
    required this.id,
    required AppVisualSpec spec,
    required this.size,
    this.color,
    this.semanticLabel,
  }) : _spec = spec;

  AppVisualSpec get spec => _spec ?? appVisualSpecFor(id);

  @override
  Widget build(BuildContext context) {
    final visual = _buildSource(context, spec.source, spec.fallback);
    if (semanticLabel == null) {
      return ExcludeSemantics(child: visual);
    }
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(child: visual),
    );
  }

  Widget _buildSource(
    BuildContext context,
    AppVisualSource source,
    AppVisualFallback? fallback,
  ) {
    return switch (source) {
      MaterialVisualSource(:final icon) => Icon(icon, size: size, color: color),
      EmojiVisualSource(:final value) => Text(
        value,
        style: TextStyle(fontSize: size),
      ),
      SvgAssetVisualSource(
        :final path,
        :final tintable,
        :final drawingBounds,
        :final strokeWidth,
      ) =>
        _assetFrame(
          (dimension) => _SvgAssetVisual(
            path: path,
            bundle: DefaultAssetBundle.of(context),
            size: dimension,
            drawingBounds: drawingBounds,
            strokeWidth: strokeWidth,
            inkColor: tintable ? color : null,
            fallbackBuilder: (error) => _buildFallback(
              fallback ??
                  const MaterialVisualFallback(Icons.image_not_supported),
              path,
              error,
            ),
          ),
        ),
      RasterAssetVisualSource(:final path) => _assetFrame(
        (dimension) => _RasterAssetVisual(
          path: path,
          bundle: DefaultAssetBundle.of(context),
          size: dimension,
          fallbackBuilder: (error) => _buildFallback(
            fallback ?? const MaterialVisualFallback(Icons.image_not_supported),
            path,
            error,
          ),
        ),
      ),
    };
  }

  Widget _assetFrame(Widget Function(double) buildAsset) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dimension = math.min(
            size,
            math.min(constraints.maxWidth, constraints.maxHeight),
          );
          if (dimension <= 0) return const SizedBox.shrink();
          return Center(
            child: SizedBox.square(
              dimension: dimension,
              child: buildAsset(dimension),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildFallback(AppVisualFallback fallback, String path, Object error) {
    if (kDebugMode) {
      debugPrint('AppVisual asset failed: id=$id path=$path error=$error');
    }
    return switch (fallback) {
      MaterialVisualFallback(:final icon) => Icon(
        icon,
        size: size,
        color: color,
      ),
      EmojiVisualFallback(:final value) => Text(
        value,
        style: TextStyle(fontSize: size),
      ),
    };
  }
}

typedef _FallbackBuilder = Widget Function(Object error);

class _SvgAssetVisual extends StatefulWidget {
  final String path;
  final AssetBundle bundle;
  final double size;
  final Color? inkColor;
  final Rect? drawingBounds;
  final double? strokeWidth;
  final _FallbackBuilder fallbackBuilder;

  const _SvgAssetVisual({
    required this.path,
    required this.bundle,
    required this.size,
    required this.inkColor,
    required this.drawingBounds,
    required this.strokeWidth,
    required this.fallbackBuilder,
  });

  @override
  State<_SvgAssetVisual> createState() => _SvgAssetVisualState();
}

class _SvgAssetVisualState extends State<_SvgAssetVisual> {
  late Future<String> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void didUpdateWidget(_SvgAssetVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.bundle != widget.bundle ||
        oldWidget.drawingBounds != widget.drawingBounds) {
      _data = _load();
    }
  }

  Future<String> _load() async {
    var data = await widget.bundle.loadString(widget.path);
    final bounds = widget.drawingBounds;
    if (bounds != null) {
      data = data.replaceFirst(
        RegExp(r'viewBox="[^"]+"'),
        'viewBox="${bounds.left} ${bounds.top} ${bounds.width} ${bounds.height}"',
      );
    }
    final picture = await vg.loadPicture(SvgStringLoader(data), null);
    picture.picture.dispose();
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.fallbackBuilder(snapshot.error!);
        }
        var data = snapshot.data;
        if (data == null) return SizedBox.square(dimension: widget.size);
        final bounds = widget.drawingBounds;
        final strokeWidth = widget.strokeWidth;
        if (bounds != null &&
            strokeWidth != null &&
            data.contains('stroke-width=')) {
          // SVG strokes normally shrink with the canvas. Common controls keep
          // their logical stroke width even when the display size changes.
          final displayStroke = math.min(strokeWidth, widget.size / 2);
          // Reserve half a stroke on each edge so thickened outlines do not
          // paint outside a compact control's requested drawing area.
          final viewportWidth =
              bounds.width * widget.size / (widget.size - displayStroke);
          final viewport = Rect.fromCenter(
            center: bounds.center,
            width: viewportWidth,
            height: viewportWidth,
          );
          data = data.replaceFirst(
            RegExp(r'viewBox="[^"]+"'),
            'viewBox="${viewport.left} ${viewport.top} ${viewport.width} ${viewport.height}"',
          );
          final sourceWidth = displayStroke * viewportWidth / widget.size;
          data = data.replaceAll(
            RegExp(r'stroke-width="[0-9.]+"'),
            'stroke-width="$sourceWidth"',
          );
        }
        return SvgPicture.string(
          data,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          // An icon must never paint over adjacent fields or menu rows.
          allowDrawingOutsideViewBox: false,
          colorMapper: widget.inkColor == null
              ? null
              : _InkColorMapper(widget.inkColor!),
          errorBuilder: (context, error, stackTrace) =>
              widget.fallbackBuilder(error),
        );
      },
    );
  }
}

class _RasterAssetVisual extends StatefulWidget {
  final String path;
  final AssetBundle bundle;
  final double size;
  final _FallbackBuilder fallbackBuilder;

  const _RasterAssetVisual({
    required this.path,
    required this.bundle,
    required this.size,
    required this.fallbackBuilder,
  });

  @override
  State<_RasterAssetVisual> createState() => _RasterAssetVisualState();
}

class _RasterAssetVisualState extends State<_RasterAssetVisual> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(_RasterAssetVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.bundle != widget.bundle) {
      _bytes = _load();
    }
  }

  Future<Uint8List> _load() async {
    final data = await widget.bundle.load(widget.path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.fallbackBuilder(snapshot.error!);
        }
        final bytes = snapshot.data;
        if (bytes == null) return SizedBox.square(dimension: widget.size);
        return Image.memory(
          bytes,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              widget.fallbackBuilder(error),
        );
      },
    );
  }
}

class _InkColorMapper extends ColorMapper {
  final Color ink;
  const _InkColorMapper(this.ink);
  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    // Recolor dark neutral outlines only; keep white interiors and state colors.
    final neutral =
        (color.r - color.g).abs() < .04 && (color.g - color.b).abs() < .04;
    return neutral && color.r < .4
        ? ink.withValues(alpha: ink.a * color.a)
        : color;
  }

  @override
  bool operator ==(Object other) =>
      other is _InkColorMapper && other.ink == ink;
  @override
  int get hashCode => ink.hashCode;
}
