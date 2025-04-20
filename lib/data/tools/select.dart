import 'package:flutter/material.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/pages/editor/editor_controller.dart';

class Select extends Tool {
  Select._();

  static final Select _currentSelect = Select._();
  static Select get currentSelect => _currentSelect;

  /// The minimum ratio of points inside a stroke or image
  /// for it to be selected.
  static const double minPercentInside = 0.7;

  SelectResult selectResult = SelectResult(
    pageIndex: -1,
    strokes: const [],
    images: const [],
    path: Path(),
  );
  bool doneSelecting = false;

  @override
  ToolId get toolId => ToolId.select;

  void unselect() {
    doneSelecting = false;
    selectResult.pageIndex = -1;
  }

  Color? getDominantStrokeColor() {
    if (!doneSelecting) return null;
    if (selectResult.strokes.isEmpty) return null;

    Map<Color, int> colorDistribution = <Color, int>{};
    for (Stroke stroke in selectResult.strokes) {
      colorDistribution.update(
        stroke.color,
        (value) => value + stroke.length,
        ifAbsent: () => stroke.length,
      );
    }
    assert(colorDistribution.isNotEmpty);

    return colorDistribution.entries.reduce((a, b) {
      return a.value > b.value ? a : b;
    }).key;
  }

  @override
  void onDragStart(DragData data, EditorController controller) {
    if (doneSelecting &&
        selectResult.pageIndex == data.pageIndex &&
        selectResult.path.contains(data.position)) {
      // Move selection in onDrawUpdate
    } else {
      doneSelecting = false;
      selectResult = SelectResult(
        pageIndex: data.pageIndex,
        strokes: [],
        images: [],
        path: Path(),
      );
      selectResult.path.moveTo(data.position.dx, data.position.dy);
    }
  }

  @override
  void onDragUpdate(DragData data, EditorController controller) {
    if (doneSelecting) {
      // Move
      for (Stroke stroke in selectResult.strokes) {
        stroke.shift(data.offset);
      }
      for (EditorImage image in selectResult.images) {
        image.dstRect = image.dstRect.shift(data.offset);
      }
      selectResult.path = selectResult.path.shift(data.offset);
    } else {
      // Select
      selectResult.path.lineTo(data.position.dx, data.position.dy);
    }

    controller.redrawStrokes(data.pageIndex);
  }

  /// Adds the indices of any [strokes] that are inside the selection area
  /// to [selectResult.indices], or moves the selection if done.
  @override
  void onDragEnd(DragData data, EditorController controller) {
    if (data.offset == Offset.zero) return;

    if (doneSelecting) {
      // Move
      controller.recordChange(EditorHistoryItem(
        type: EditorHistoryItemType.move,
        pageIndex: data.pageIndex,
        strokes: selectResult.strokes,
        images: selectResult.images,
        offset: Rect.fromLTRB(
          data.offset.dx,
          data.offset.dy,
          data.offset.dx,
          data.offset.dy,
        ),
      ));
      controller.autosaveAfterDelay();
    } else {
      // Select
      selectResult.path.close();
      doneSelecting = true;

      final page = controller.getPage(data.pageIndex);

      for (int i = 0; i < page.strokes.length; i++) {
        final stroke = page.strokes[i];
        final percentInside =
            polygonPercentInside(selectResult.path, stroke.lowQualityPolygon);
        if (percentInside > minPercentInside) {
          selectResult.strokes.add(stroke);
        }
      }

      for (int i = 0; i < page.images.length; i++) {
        final image = page.images[i];
        final percentInside =
            rectPercentInside(selectResult.path, image.dstRect);
        if (percentInside >= minPercentInside) {
          selectResult.images.add(image);
        }
      }

      if (selectResult.isEmpty) {
        Select.currentSelect.unselect();
      }
    }

    controller.markNeedsRepaint();
  }

  static double rectPercentInside(Path selection, Rect rect) {
    const int gridSize = 5;
    final double gridCellWidth = rect.width / (gridSize - 1);
    final double gridCellHeight = rect.height / (gridSize - 1);

    int pointsInside = 0;
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (selection.contains(Offset(
          rect.left + gridCellWidth * x,
          rect.top + gridCellHeight * y,
        ))) {
          pointsInside++;
        }
      }
    }

    // times 1.25 because the grid is not very accurate
    return pointsInside / (gridSize * gridSize) * 1.25;
  }

  static double polygonPercentInside(Path selection, List<Offset> polygon) {
    int pointsInside = 0;
    for (Offset point in polygon) {
      if (selection.contains(point)) {
        pointsInside++;
      }
    }
    return pointsInside / polygon.length;
  }
}

class SelectResult {
  int pageIndex;
  final List<Stroke> strokes;
  final List<EditorImage> images;
  Path path;

  SelectResult({
    required this.pageIndex,
    required this.strokes,
    required this.images,
    required this.path,
  });

  bool get isEmpty {
    return strokes.isEmpty && images.isEmpty;
  }

  SelectResult copyWith({
    int? pageIndex,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    Path? path,
  }) {
    return SelectResult(
      pageIndex: pageIndex ?? this.pageIndex,
      strokes: strokes ?? this.strokes,
      images: images ?? this.images,
      path: path ?? this.path,
    );
  }
}
