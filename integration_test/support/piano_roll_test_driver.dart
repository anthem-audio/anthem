/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/app.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/time_range_viewport.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'app_test_session.dart';
import 'waits.dart';

/// Fixture setup may use controllers. Tested edits and shortcuts use real input.
/// Every target is calculated from current rendered metrics and canvas bounds.
class PianoRollTestDriver {
  final AppTestSession session;
  Map<String, Object?>? _lastInputTarget;

  PianoRollTestDriver(this.session) {
    session.registerFailureDiagnostics('pianoRoll', () => viewportDiagnostics);
  }

  WidgetTester get tester => session.tester;
  PianoRollViewModel get viewModel => session.services.pianoRollViewModel;
  PianoRollController get controller => session.services.pianoRollController;
  PianoRollStateMachineData get renderedMetrics => controller.stateMachine.data;
  Finder get canvasFinder => find.byKey(pianoRollCanvasKey);

  Rect? get _laidOutCanvasRect {
    final elements = canvasFinder.evaluate().toList();
    if (elements.length != 1) return null;
    final renderObject = elements.single.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return tester.getRect(canvasFinder);
  }

  Rect get canvasRect =>
      _laidOutCanvasRect ??
      (throw StateError(
        'Piano roll canvas is not laid out: $viewportDiagnostics',
      ));

  ShortcutProviderController? get _shortcutController {
    final elements = canvasFinder.evaluate().toList();
    if (elements.length != 1) return null;
    return Provider.of<ShortcutProviderController>(
      elements.single,
      listen: false,
    );
  }

  Map<String, Object?> get viewportDiagnostics => {
    'lastInputTarget': _lastInputTarget,
    ...session.sessionDiagnostics,
    'patternId': session.project.sequence.activePatternID,
    'canvasBounds': _laidOutCanvasRect?.toString(),
    'targetTimeRange': [viewModel.timeRange.start, viewModel.timeRange.end],
    'renderedTimeRange': [
      renderedMetrics.renderedTimeViewStart,
      renderedMetrics.renderedTimeViewEnd,
    ],
    'targetPitchAtTop': viewModel.keyValueAtTop,
    'renderedPitchAtTop': renderedMetrics.renderedKeyValueAtTop,
    'renderedKeyHeight': renderedMetrics.renderedKeyHeight,
    'tool': viewModel.tool.name,
    'activeShortcutConsumer': _shortcutController?.activeConsumer,
    'visibleNoteIds': viewModel.visibleNotes
        .getAnnotations()
        .map((note) => note.metadata.id)
        .toList(),
  };

  /// Positions the fixture immediately, then verifies a matching rendered frame.
  /// The current product uses AutoSnap; verify its interval at the chosen scale.
  Future<void> configureFixture({
    required Id patternId,
    required double timeStart,
    required double timeEnd,
    required double pitchAtTop,
    required double keyHeight,
    required EditorTool tool,
    required int noteLength,
    required double noteVelocity,
    required double notePan,
    required int expectedSnapTicks,
  }) async {
    session.services.projectController.openPatternInPianoRoll(patternId);
    viewModel.timeRangeViewport.setRange(
      start: timeStart,
      end: timeEnd,
      transition: TimeRangeTransition.immediate,
    );
    viewModel.keyValueAtTop = pitchAtTop;
    viewModel.keyValueAtTopAnimationShouldSnap = true;
    viewModel.keyHeight = keyHeight;
    viewModel.tool = tool;
    viewModel.stemEditorOpen = false;
    viewModel.selectedNotes.clear();
    viewModel.cursorNoteLength = noteLength;
    viewModel.cursorNoteVelocity = noteVelocity;
    viewModel.cursorNotePan = notePan;
    await waitForRenderedViewport();
    expect(session.project.sequence.activePatternID, patternId);
    expect(viewModel.timeRange.start, timeStart);
    expect(viewModel.timeRange.end, timeEnd);
    expect(
      controller
          .divisionChangesForPatternView(viewWidthInPixels: canvasRect.width)
          .map((division) => division.divisionSnapSize),
      everyElement(expectedSnapTicks),
      reason:
          'The fixture must establish the intended automatic snap interval.',
    );
  }

  static bool _near(double a, double b) => (a - b).abs() < 0.000001;

  Future<void> waitForRenderedViewport() async {
    // Finish a layout/paint before inspecting metrics or frame annotations.
    await tester.pump();
    await waitUntil(
      tester,
      conditionDescription: 'piano roll layout and rendered viewport match',
      isReady: () {
        final rect = _laidOutCanvasRect;
        return rect != null &&
            rect.width > 0 &&
            rect.height > 0 &&
            renderedMetrics.viewSize == rect.size &&
            _near(
              renderedMetrics.renderedTimeViewStart,
              viewModel.timeRange.start,
            ) &&
            _near(
              renderedMetrics.renderedTimeViewEnd,
              viewModel.timeRange.end,
            ) &&
            _near(
              renderedMetrics.renderedKeyValueAtTop,
              viewModel.keyValueAtTop,
            ) &&
            _near(renderedMetrics.renderedKeyHeight, viewModel.keyHeight);
      },
      collectTimeoutDiagnostics: () => viewportDiagnostics,
      checkHealth: session.checkEngine,
    );
  }

  /// Converts an unsnapped time and the center of a pitch row to a visible point.
  /// This never scrolls to a target. Tests must arrange the viewport explicitly.
  Offset emptyCanvasPoint({required double rawTick, required int pitch}) {
    final rect = canvasRect;
    final local = Offset(
      timeToPixels(
        timeViewStart: renderedMetrics.renderedTimeViewStart,
        timeViewEnd: renderedMetrics.renderedTimeViewEnd,
        viewPixelWidth: rect.width,
        time: rawTick,
      ),
      keyValueToPixels(
        keyValue: pitch + 0.5,
        keyValueAtTop: renderedMetrics.renderedKeyValueAtTop,
        keyHeight: renderedMetrics.renderedKeyHeight,
      ),
    );
    final global = rect.topLeft + local;
    _lastInputTarget = {
      'tick': rawTick,
      'pitch': pitch,
      'localPoint': local.toString(),
      'globalPoint': global.toString(),
    };
    if (!rect.contains(global) ||
        !tester.getRect(find.byKey(mainWindowKey)).contains(global)) {
      throw StateError(
        'Drawing target at tick $rawTick, pitch $pitch is outside the visible '
        'piano roll. Target: $global; viewport diagnostics: $viewportDiagnostics',
      );
    }
    final hit = viewModel.hitTestContent(local);
    if (hit.note != null || hit.resizeHandle != null) {
      throw StateError('Drawing target is occupied: $viewportDiagnostics');
    }
    return global;
  }

  Future<void> drawNote({
    required double rawTick,
    required int pitch,
    required double moveToTick,
  }) async {
    await waitForRenderedViewport();
    if (viewModel.tool != EditorTool.pencil) {
      throw StateError('Note drawing requires the pencil tool.');
    }
    final start = emptyCanvasPoint(rawTick: rawTick, pitch: pitch);
    final end = emptyCanvasPoint(rawTick: moveToTick, pitch: pitch);
    await session.withMouseGesture(
      start: start,
      action: (pointer) async {
        await tester.pump();
        await pointer.moveTo(end);
        await tester.pump();
      },
    );
    await tester.pump();
    _requireKeyboardActivation();
  }

  /// Uses frame annotations as locators, checking clipping, overlapping notes,
  /// and resize handles. This is not independent proof of musical placement.
  Offset visibleNoteBodyPoint(Id noteId) {
    final rect = canvasRect;
    final bounds = (Offset.zero & rect.size).intersect(
      tester.getRect(find.byKey(mainWindowKey)).shift(-rect.topLeft),
    );
    final annotations = viewModel.visibleNotes.getAnnotations().where(
      (note) => note.metadata.realNoteId == noteId,
    );
    for (final annotation in annotations) {
      final visible = annotation.rect.intersect(bounds);
      if (visible.isEmpty) continue;
      for (final fraction in [0.5, 0.25, 0.75]) {
        final local = Offset(
          visible.left + visible.width * fraction,
          visible.center.dy,
        );
        final hit = viewModel.hitTestContent(local);
        if (hit.note?.metadata.realNoteId == noteId &&
            hit.resizeHandle == null) {
          return rect.topLeft + local;
        }
      }
    }
    throw StateError(
      'Note $noteId has no visible, unobscured body target. '
      'Viewport diagnostics: $viewportDiagnostics',
    );
  }

  Future<void> waitForNoteRendering(Id noteId, {required bool visible}) async {
    await tester.pump();
    await waitUntil(
      tester,
      conditionDescription:
          'note $noteId ${visible ? 'appears' : 'disappears'} in piano roll',
      isReady: () =>
          viewModel.visibleNotes.getAnnotations().any(
            (note) => note.metadata.realNoteId == noteId,
          ) ==
          visible,
      collectTimeoutDiagnostics: () => viewportDiagnostics,
      checkHealth: session.checkEngine,
    );
    if (visible) visibleNoteBodyPoint(noteId);
  }

  void _requireKeyboardActivation() {
    if (_shortcutController?.activeConsumer !=
        '${session.project.id}-piano-roll') {
      throw StateError(
        'Activate the piano roll through mouse input before sending shortcuts. '
        'Viewport diagnostics: $viewportDiagnostics',
      );
    }
  }

  LogicalKeyboardKey get primaryPhysicalKey =>
      primaryModifierKey == LogicalKeyboardKey.meta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  Future<void> undo() => _sendHistoryShortcut(redo: false);
  Future<void> redo() => _sendHistoryShortcut(redo: true);

  Future<void> _sendHistoryShortcut({required bool redo}) async {
    _requireKeyboardActivation();
    await session.withKeysHeld([
      primaryPhysicalKey,
      if (redo) LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.keyZ,
    ], () => tester.pump());
  }
}
