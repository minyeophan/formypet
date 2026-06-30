import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/widgets/app_visual.dart';

Finder findAppVisual(AppVisualId id) => find.byWidgetPredicate(
  (widget) => widget is AppVisual && widget.id == id,
  description: 'AppVisual with id $id',
);
