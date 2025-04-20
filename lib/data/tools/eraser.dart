import 'dart:ui';

import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/editor_history.dart';

import 'package:saber/data/tools/_tool.dart';
import 'package:saber/pages/editor/editor_controller.dart';

double square(double x) => x * x;
double sqrDistanceBetween(Offset p1, Offset p2) =>
    square(p1.dx - p2.dx) + square(p1.dy - p2.dy);

class Eraser extends Tool {
  final double size;
  late final double sqrSize = square(size);

  List<Stroke> _erased = [];

  Eraser({this.size = 10});

  @override
  ToolId get toolId => ToolId.eraser;

  /// Returns any [strokes] that are close to the given [eraserPos].
  List<Stroke> overlappingStrokes(Offset eraserPos, List<Stroke> strokes) {
    final List<Stroke> overlapping = [];
    for (int i = 0; i < strokes.length; i++) {
      final Stroke stroke = strokes[i];
      if (_shouldStrokeBeErased(eraserPos, stroke, sqrSize)) {
        overlapping.add(stroke);
      }
    }
    return overlapping;
  }

  @override
  void onDragStart(DragData data, EditorController controller) {
    onDragUpdate(data, controller);
    controller.setPencilSound(true);
  }

  @override
  void onDragUpdate(DragData data, EditorController controller) {
    final page = controller.getPage(data.pageIndex);
    for (Stroke stroke in overlappingStrokes(data.position, page.strokes)) {
      page.strokes.remove(stroke);
      _erased.add(stroke);
    }
    page.redrawStrokes();
    controller.removeExcessPages();
  }

  /// Returns the strokes that have been erased during this drag.
  @override
  List<Stroke> onDragEnd(DragData data, EditorController controller) {
    controller.setPencilSound(false);
    final List<Stroke> erased = _erased;
    _erased = [];

    controller.recordChange(EditorHistoryItem(
      type: EditorHistoryItemType.erase,
      pageIndex: data.pageIndex,
      strokes: erased,
      images: [],
    ));
    controller.markNeedsRepaint();
    controller.autosaveAfterDelay();

    return erased;
  }

  static bool _shouldStrokeBeErased(
      Offset eraserPos, Stroke stroke, double sqrSize) {
    if (stroke.length <= 3) {
      if (stroke.lowQualityPath.contains(eraserPos)) return true;
    }

    /// skip checking every few vertices for performance
    final int verticesToSkip = switch (stroke.lowQualityPolygon.length) {
      < 100 => 0,
      < 1000 => 1,
      _ => 2,
    };

    for (int i = 0;
        i < stroke.lowQualityPolygon.length;
        i += verticesToSkip + 1) {
      final Offset strokeVertex = stroke.lowQualityPolygon[i];
      if (sqrDistanceBetween(strokeVertex, eraserPos) <= sqrSize) return true;
    }
    return false;
  }
}
