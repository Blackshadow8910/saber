import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor_controller.dart';

class Pen extends Tool {
  @protected
  @visibleForTesting
  Pen({
    required this.name,
    required this.sizeMin,
    required this.sizeMax,
    required this.sizeStep,
    required this.icon,
    required this.options,
    required this.pressureEnabled,
    required this.color,
    required this.toolId,
  });

  Pen.fountainPen()
      : name = t.editor.pens.fountainPen,
        sizeMin = 1,
        sizeMax = 25,
        sizeStep = 1,
        icon = fountainPenIcon,
        options = Prefs.lastFountainPenOptions.value,
        pressureEnabled = true,
        color = Color(Prefs.lastFountainPenColor.value),
        toolId = ToolId.fountainPen;

  Pen.ballpointPen()
      : name = t.editor.pens.ballpointPen,
        sizeMin = 1,
        sizeMax = 25,
        sizeStep = 1,
        icon = ballpointPenIcon,
        options = Prefs.lastBallpointPenOptions.value,
        pressureEnabled = false,
        color = Color(Prefs.lastBallpointPenColor.value),
        toolId = ToolId.ballpointPen;

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax =
      ((sizeMax - sizeMin) / sizeStep).round();
  final IconData icon;

  @override
  final ToolId toolId;

  static const IconData fountainPenIcon = FontAwesomeIcons.penFancy;
  static const IconData ballpointPenIcon = FontAwesomeIcons.pen;

  static Stroke? currentStroke;
  Color color;
  bool pressureEnabled;
  StrokeOptions options;

  static Pen _currentPen = Pen.fountainPen();
  static Pen get currentPen => _currentPen;
  static set currentPen(Pen currentPen) {
    assert(currentPen is! Highlighter,
        'Use Highlighter.currentHighlighter instead');
    assert(currentPen is! Pencil, 'Use Pencil.currentPencil instead');
    _currentPen = currentPen;
  }

  @override
  void onDragStart(DragData data, EditorController controller) {
    currentStroke = Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(
        isComplete: false,
      ),
      pageIndex: data.pageIndex,
      penType: runtimeType.toString(),
    );
    onDragUpdate(data, controller);
    controller.setPencilSound(true);
  }

  @override
  void onDragUpdate(DragData data, EditorController controller) {
    currentStroke!.addPoint(data.position, data.pressure);
    controller.redrawStrokes(data.pageIndex);
  }

  @override
  Stroke onDragEnd(DragData data, EditorController controller) {
    final Stroke stroke = currentStroke!
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
    currentStroke = null;
    controller.setPencilSound(false);

    if (!stroke.isEmpty) {
      if (Prefs.autoStraightenLines.value &&
          this is! ShapePen &&
          stroke.isStraightLine()) {
        stroke.convertToLine();
      }

      controller.addStroke(stroke);
      controller.recordChange(EditorHistoryItem(
        type: EditorHistoryItemType.draw,
        pageIndex: data.pageIndex,
        strokes: [stroke],
        images: [],
      ));
      controller.autosaveAfterDelay();
      controller.markNeedsRepaint();
    }

    return stroke;
  }

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(
    size: 5,
  );

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get shapePenOptions => defaultOptions.copyWith();
  static StrokeOptions get highlighterOptions => defaultOptions.copyWith(
        size: 50,
      );
  static StrokeOptions get pencilOptions => defaultOptions.copyWith(
        streamline: 0.1,
        start: StrokeEndOptions.start(taperEnabled: true, customTaper: 1),
        end: StrokeEndOptions.end(taperEnabled: true, customTaper: 1),
      );

  get dragPageIndex => null;
}
