import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/pages/editor/editor_controller.dart';

class LaserPointer extends Tool {
  LaserPointer._();

  static final LaserPointer _currentLaserPointer = LaserPointer._();
  static LaserPointer get currentLaserPointer => _currentLaserPointer;

  @override
  ToolId get toolId => ToolId.laserPointer;

  static const outerColor = Colors.red;
  final pressureEnabled = false;
  final options = StrokeOptions(
    smoothing: 0.7,
    streamline: 0.7,
  );

  /// List of timings that correspond to the delay between each point
  /// in the stroke. The first point has a delay of 0.
  ///
  /// This is used to fade out each point in the stroke one by one.
  List<Duration> strokePointDelays = [];

  /// Stopwatch used to find the time elapsed since the last point.
  final Stopwatch _stopwatch = Stopwatch();

  /// Whether the user is currently drawing with the laser.
  /// This is used to prevent strokes fading out until the user
  /// has finished drawing.
  static bool isDrawing = false;

  @override
  void onDragStart(DragData data, EditorController controller) {
    isDrawing = true;
    controller.setPencilSound(true);
    Pen.currentStroke = LaserStroke(
      color: outerColor,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(),
      pageIndex: data.pageIndex,
      penType: runtimeType.toString(),
    );

    strokePointDelays = [];
    _stopwatch.reset();
    onDragUpdate(data, controller);
    _stopwatch.start();
  }

  @override
  void onDragUpdate(DragData data, EditorController controller) {
    isDrawing = true;
    Pen.currentStroke?.addPoint(data.position);
    strokePointDelays.add(_stopwatch.elapsed);
    _stopwatch.reset();
    controller.redrawStrokes(data.pageIndex);
  }

  @override
  LaserStroke onDragEnd(DragData data, EditorController controller) {
    isDrawing = false;
    final stroke = (Pen.currentStroke! as LaserStroke);

    fadeOutStroke(
      stroke: stroke,
      strokePointDelays: strokePointDelays,
      redrawPage: () => {controller.redrawStrokes(stroke.pageIndex)},
      deleteStroke: controller.removeStroke,
    );
    stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
    Pen.currentStroke = null;

    controller.addStroke(stroke);
    controller.redrawStrokes(data.pageIndex);
    return stroke;
  }

  static const _fadeOutDelay = Duration(seconds: 2);
  @visibleForTesting
  static void fadeOutStroke({
    required Stroke stroke,
    required List<Duration> strokePointDelays,
    required VoidCallback redrawPage,
    required void Function(Stroke) deleteStroke,
  }) async {
    await Future.delayed(_fadeOutDelay);

    for (final delay in strokePointDelays) {
      await Future.delayed(delay);

      stroke.popFirstPoint();
      redrawPage();

      if (isDrawing) {
        // if the user starts drawing again, wait until they stop
        const waitTime = Duration(milliseconds: 100);
        while (isDrawing) await Future.delayed(waitTime);
        // now wait the normal delay before continuing
        await Future.delayed(_fadeOutDelay - waitTime);
      }
    }

    deleteStroke(stroke);
    redrawPage();
  }
}

class LaserStroke extends Stroke {
  LaserStroke({
    required super.color,
    required super.pressureEnabled,
    required super.options,
    required super.pageIndex,
    required super.penType,
  });
  @visibleForTesting
  LaserStroke.convertStroke(Stroke stroke)
      : super(
          color: stroke.color,
          pressureEnabled: stroke.pressureEnabled,
          options: stroke.options
            ..streamline = 0.7
            ..smoothing = 0.7,
          pageIndex: stroke.pageIndex,
          penType: stroke.penType,
        ) {
    points.addAll(stroke.points);
  }

  List<Offset>? _innerPolygon;
  List<Offset> get innerPolygon => _innerPolygon ??= getStroke(
        points,
        options: options.copyWith(size: options.size * 0.4),
      );

  Path? _innerPath;
  Path get innerPath =>
      _innerPath ??= Stroke.smoothPathFromPolygon(innerPolygon);

  /// Disables low quality to make sure the polygon exactly matches
  /// [innerPolygon].
  @override
  List<Offset> get lowQualityPolygon => highQualityPolygon;

  @override
  void shift(Offset offset) {
    _innerPolygon?.shift(offset);
    _innerPath?.shift(offset);
    super.shift(offset);
  }

  @override
  void markPolygonNeedsUpdating() {
    _innerPolygon = null;
    _innerPath = null;
    super.markPolygonNeedsUpdating();
  }
}
