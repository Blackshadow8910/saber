import 'package:logging/logging.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/editor/pencil_sound.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/laser_pointer.dart';

import 'package:saber/pages/editor/editor.dart';

class EditorController {
  EditorController(this.state);

  EditorState state;

  Logger get log => state.log;
  EditorHistory get history => state.history;
  EditorCoreInfo get coreInfo => state.coreInfo;

  Function(EditorHistoryItem) get recordChange => history.recordChange;

  EditorPage getPage(int pageIndex) {
    return coreInfo.pages[pageIndex];
  }

  void redrawStrokes(int pageIndex) {
    getPage(pageIndex).redrawStrokes();
  }

  Function() get markNeedsRepaint => state.markNeedsRepaint;

  void addStroke(Stroke stroke) {
    final page = getPage(stroke.pageIndex);
    final strokes = (stroke is LaserStroke) ? page.laserStrokes : page.strokes;
    if (strokes.contains(stroke))
      throw Exception('Page already contains stroke');

    strokes.add(stroke);
  }

  void removeStroke(Stroke stroke) {
    final page = getPage(stroke.pageIndex);
    final strokes = (stroke is LaserStroke) ? page.laserStrokes : page.strokes;

    strokes.remove(stroke);
  }

  void setPencilSound(bool val) {
    val &= Prefs.pencilSound.value != PencilSoundSetting.off;
    if (val) {
      PencilSound.resume();
    } else {
      PencilSound.pause();
    }
  }

  void setCanRedo(bool val) {
    history.canRedo = val;
  }

  Function() get autosaveAfterDelay => state.autosaveAfterDelay;

  Function() get removeExcessPages => state.removeExcessPages;
}
