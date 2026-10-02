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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'support/app_test_session.dart';
import 'support/piano_roll_test_driver.dart';

Future<PatternModel> _preparePattern(
  AppTestSession session,
  PianoRollTestDriver pianoRoll,
) async {
  final pattern = PatternModel(
    idAllocator: session.project.idAllocator,
    name: 'Note editing fixture',
  );
  // Prerequisites bypass undo history; the tested note is added only by input.
  session.project.sequence.patterns[pattern.id] = pattern;
  session.services.trackController.setActiveTrack(
    session.project.trackOrder.first,
  );
  await pianoRoll.configureFixture(
    patternId: pattern.id,
    timeStart: 0,
    timeEnd: 384,
    pitchAtTop: 64,
    keyHeight: 16,
    tool: EditorTool.pencil,
    noteLength: 96,
    noteVelocity: 0.625,
    notePan: -0.25,
    expectedSnapTicks: 24,
  );
  await session.waitForEngineModel(
    conditionDescription: 'empty fixture pattern in engine',
    matches: (model) => _engineNotes(model, pattern.id)?.isEmpty == true,
  );
  return pattern;
}

Map<String, dynamic>? _engineNotes(Map<String, dynamic> model, Id patternId) {
  final sequence = model['sequence'] as Map<String, dynamic>;
  final patterns = sequence['patterns'] as Map<String, dynamic>;
  final pattern = patterns['$patternId'] as Map<String, dynamic>?;
  return pattern?['notes'] as Map<String, dynamic>?;
}

// Literal expectations are independent of the driver's coordinate conversion.
// The input at tick 203 snaps down to 192; its small move stays in that step.
Map<String, Object> _expectedNote(Id noteId) => {
  'id': noteId,
  'key': 60,
  'offset': 192,
  'length': 96,
  'velocity': 0.625,
  'pan': -0.25,
};

Future<void> _verifyNotePresent({
  required AppTestSession session,
  required PianoRollTestDriver pianoRoll,
  required PatternModel pattern,
  required Id noteId,
  required String phase,
}) async {
  expect(pattern.notes.keys, [noteId]);
  final note = pattern.notes[noteId]!;
  final expected = _expectedNote(noteId);
  expect(note.toJson(), expected);
  expect(pattern.previewNotes, isEmpty);
  expect(pattern.noteOverrides, isEmpty);
  expect(pianoRoll.controller.activeInteractionFamily, isNull);
  await pianoRoll.waitForNoteRendering(noteId, visible: true);
  expect(
    pianoRoll.viewModel.visibleNotes.getAnnotations().map(
      (note) => note.metadata.realNoteId,
    ),
    [noteId],
  );
  expect(
    pianoRoll.canvasRect.contains(pianoRoll.visibleNoteBodyPoint(noteId)),
    isTrue,
  );
  final model = await session.waitForEngineModel(
    conditionDescription: '$phase note properties in engine',
    matches: (model) {
      final notes = _engineNotes(model, pattern.id);
      if (notes == null || notes.length != 1) return false;
      final engineNote = notes['$noteId'] as Map<String, dynamic>?;
      return engineNote != null &&
          expected.entries.every(
            (entry) => engineNote[entry.key] == entry.value,
          );
    },
  );
  await session.writeSessionDiagnostics(
    phase,
    additionalDiagnostics: {
      'pianoRoll': pianoRoll.viewportDiagnostics,
      'dartNote': note.toJson(),
      'engineNotes': _engineNotes(model, pattern.id),
    },
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testAppScenario(
    'draw a note, resize the window, then keyboard undo and redo',
    (tester) async {
      final session = AppTestSession(tester, name: 'note-editing');
      await session.start();
      final pianoRoll = PianoRollTestDriver(session);
      final pattern = await _preparePattern(session, pianoRoll);

      await expectLater(
        () => pianoRoll.undo(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Activate the piano roll through mouse input'),
          ),
        ),
      );
      for (final target in [
        (tick: -24.0, pitch: 60),
        (tick: 203.0, pitch: 0),
      ]) {
        await expectLater(
          () => pianoRoll.drawNote(
            rawTick: target.tick,
            pitch: target.pitch,
            moveToTick: target.tick,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('outside the visible piano roll'),
                contains('renderedTimeRange'),
              ),
            ),
          ),
        );
      }
      expect(pattern.notes, isEmpty);
      expect(pattern.previewNotes, isEmpty);

      await pianoRoll.drawNote(rawTick: 203, pitch: 60, moveToTick: 207);
      expect(pattern.notes, hasLength(1));
      final noteId = pattern.notes.keys.single;
      await _verifyNotePresent(
        session: session,
        pianoRoll: pianoRoll,
        pattern: pattern,
        noteId: noteId,
        phase: 'drawn',
      );

      final originalCanvas = pianoRoll.canvasRect;
      final originalTimeEnd = pianoRoll.renderedMetrics.renderedTimeViewEnd;
      await session.resizeWindow(const Size(1100, 720));
      await pianoRoll.waitForRenderedViewport();
      expect(pianoRoll.canvasRect.width, lessThan(originalCanvas.width));
      expect(
        pianoRoll.renderedMetrics.renderedTimeViewEnd,
        lessThan(originalTimeEnd),
      );
      await _verifyNotePresent(
        session: session,
        pianoRoll: pianoRoll,
        pattern: pattern,
        noteId: noteId,
        phase: 'resized',
      );

      await pianoRoll.undo();
      expect(pattern.notes, isEmpty);
      expect(pattern.previewNotes, isEmpty);
      await pianoRoll.waitForNoteRendering(noteId, visible: false);
      expect(pianoRoll.viewModel.visibleNotes.getAnnotations(), isEmpty);
      final undoneModel = await session.waitForEngineModel(
        conditionDescription: 'undo removes the note from engine',
        matches: (model) => _engineNotes(model, pattern.id)?.isEmpty == true,
      );
      await session.writeSessionDiagnostics(
        'undone',
        additionalDiagnostics: {
          'pianoRoll': pianoRoll.viewportDiagnostics,
          'engineNotes': _engineNotes(undoneModel, pattern.id),
        },
      );

      await pianoRoll.redo();
      await _verifyNotePresent(
        session: session,
        pianoRoll: pianoRoll,
        pattern: pattern,
        noteId: noteId,
        phase: 'redone',
      );
      expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
      expect(pianoRoll.renderedMetrics.activePointerId, isNull);
      await session.dispose();
      expect(session.project.engine.processExitCode, isNotNull);
    },
  );

  testAppScenario(
    'input helpers release modifiers and pointer after action failure',
    (tester) async {
      final session = AppTestSession(tester, name: 'input-helper-failure');
      await session.start();
      final pianoRoll = PianoRollTestDriver(session);
      await _preparePattern(session, pianoRoll);
      final modifiers = Provider.of<KeyboardModifiers>(
        tester.element(pianoRoll.canvasFinder),
        listen: false,
      );
      final failure = StateError('Intentional input action failure');
      await expectLater(
        () => session.withKeysHeld(
          [pianoRoll.primaryPhysicalKey, LogicalKeyboardKey.shiftLeft],
          () async {
            expect(modifiers.primary && modifiers.shift, isTrue);
            throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
      expect(modifiers.primary || modifiers.shift, isFalse);
      expect(pianoRoll.renderedMetrics.isCtrlPressed, isFalse);
      expect(pianoRoll.renderedMetrics.isShiftPressed, isFalse);

      await expectLater(
        () => session.withMouseGesture(
          start: pianoRoll.emptyCanvasPoint(rawTick: 203, pitch: 60),
          action: (_) async {
            expect(pianoRoll.renderedMetrics.activePointerId, isNotNull);
            throw failure;
          },
        ),
        throwsA(same(failure)),
      );
      expect(pianoRoll.renderedMetrics.activePointerId, isNull);
      expect(pianoRoll.controller.activeInteractionFamily, isNull);
      await session.dispose();
      expect(session.project.engine.processExitCode, isNotNull);
    },
  );
}
