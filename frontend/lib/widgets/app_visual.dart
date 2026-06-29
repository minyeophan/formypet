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

  @visibleForTesting
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
      SvgAssetVisualSource(:final path, :final tintable) => SizedBox.square(
        dimension: size,
        child: _SvgAssetVisual(
          path: path,
          bundle: DefaultAssetBundle.of(context),
          size: size,
          colorFilter: tintable && color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
          fallbackBuilder: (error) => _buildFallback(fallback!, path, error),
        ),
      ),
      RasterAssetVisualSource(:final path) => SizedBox.square(
        dimension: size,
        child: _RasterAssetVisual(
          path: path,
          bundle: DefaultAssetBundle.of(context),
          size: size,
          fallbackBuilder: (error) => _buildFallback(fallback!, path, error),
        ),
      ),
    };
  }

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
  final ColorFilter? colorFilter;
  final _FallbackBuilder fallbackBuilder;

  const _SvgAssetVisual({
    required this.path,
    required this.bundle,
    required this.size,
    required this.colorFilter,
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
    if (oldWidget.path != widget.path || oldWidget.bundle != widget.bundle) {
      _data = _load();
    }
  }

  Future<String> _load() async {
    final data = await widget.bundle.loadString(widget.path);
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
        final data = snapshot.data;
        if (data == null) return SizedBox.square(dimension: widget.size);
        return SvgPicture.string(
          data,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          colorFilter: widget.colorFilter,
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
