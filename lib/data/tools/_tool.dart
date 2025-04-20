import 'package:flutter/material.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor_controller.dart';

class DragData {
  DragData(this.position, this.offset, this.pageIndex, {this.pressure});

  /// Position of the cursor at the time of dragging
  final Offset position;

  /// Movement in last frame for update, total offset for stroke end
  final Offset offset;

  final int pageIndex;
  final double? pressure;

  // Returns a new data object representing a drag by an offset.
  DragData dragBy(Offset dragOffset, {double? dragPressure}) {
    return DragData(position + dragOffset, dragOffset, pageIndex,
        pressure: dragPressure ?? pressure);
  }

  // Returns a new data object representing a drag to a position.
  DragData dragTo(Offset dragPosition, {double? dragPressure}) {
    return DragData(dragPosition, dragPosition - position, pageIndex,
        pressure: dragPressure ?? pressure);
  }

  static DragData at(Offset position, {double? pressure}) {
    return DragData(position, Offset.zero, 0, pressure: pressure);
  }
}

abstract class Tool {
  @protected
  @visibleForTesting
  const Tool();

  /// An identifier for the tool,
  /// used to save the last-used tool in [Prefs.lastTool].
  ToolId get toolId;

  void onDragStart(DragData data, EditorController controller);
  void onDragUpdate(DragData data, EditorController controller);
  void onDragEnd(DragData data, EditorController controller);

  static const Tool textEditing = _TextEditingTool();
}

class _TextEditingTool extends Tool {
  const _TextEditingTool();

  @override
  void onDragStart(DragData data, EditorController controller) {}

  @override
  void onDragUpdate(DragData data, EditorController controller) {}

  @override
  void onDragEnd(DragData data, EditorController controller) {}

  @override
  ToolId get toolId => ToolId.textEditing;
}

enum ToolId {
  fountainPen('fountainPen'),
  ballpointPen('ballpointPen'),
  highlighter('Highlighter'),
  pencil('Pencil'),
  shapePen('ShapePen'),
  eraser('Eraser'),
  select('Select'),
  textEditing('TextEditingTool'),
  laserPointer('LaserPointer');

  final String id;
  const ToolId(this.id);
}
