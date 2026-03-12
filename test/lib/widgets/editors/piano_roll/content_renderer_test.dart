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

import 'dart:ui';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/content_renderer.dart';
import 'package:anthem/widgets/editors/piano_roll/note_label_image_cache.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _StoppedEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();

  @override
  bool get isRunning => false;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PianoRollPainter', () {
    late ProjectModel project;
    late PatternModel pattern;
    late PianoRollViewModel viewModel;

    setUp(() {
      noteLabelImageCache = NoteLabelImageCache();

      project = ProjectModel.create()..engine = _StoppedEngine();
      pattern = PatternModel.create(name: 'Pattern');
      project.sequence.patterns[pattern.id] = pattern;
      project.sequence.activePatternID = pattern.id;

      viewModel = PianoRollViewModel(
        keyHeight: 20,
        keyValueAtTop: 64,
        timeView: TimeRange(0, 1000),
      );
    });

    void paintCurrentFrame({
      required double timeViewStart,
      required double timeViewEnd,
      required double keyValueAtTop,
      Size size = const Size(100, 160),
    }) {
      final painter = PianoRollPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        keyValueAtTop: keyValueAtTop,
        viewModel: viewModel,
        project: project,
        devicePixelRatio: 1,
        shouldGreyOut: false,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.observablePaint(canvas, size);
      recorder.endRecording();
    }

    test('skips subpixel notes without aborting later note rendering', () {
      final tinyLeadingNote = NoteModel(
        key: 60,
        velocity: 0.8,
        length: 5,
        offset: 0,
        pan: 0,
      );
      final visibleLaterNote = NoteModel(
        key: 60,
        velocity: 0.8,
        length: 120,
        offset: 500,
        pan: 0,
      );

      pattern.notes[tinyLeadingNote.id] = tinyLeadingNote;
      pattern.notes[visibleLaterNote.id] = visibleLaterNote;

      expect(
        () => paintCurrentFrame(
          timeViewStart: 0,
          timeViewEnd: 1000,
          keyValueAtTop: 64,
        ),
        returnsNormally,
      );

      final visibleNotes = viewModel.visibleNotes.getAnnotations().toList();
      final resizeAreas = viewModel.visibleResizeAreas
          .getAnnotations()
          .toList();

      expect(visibleNotes, hasLength(1));
      expect(visibleNotes.single.metadata.id, visibleLaterNote.id);
      expect(resizeAreas, hasLength(1));
      expect(resizeAreas.single.metadata.id, visibleLaterNote.id);
      expect(resizeAreas.single.rect.width, greaterThan(0));
    });

    test('missing note label cache does not abort later notes', () {
      viewModel.keyHeight = 32;

      final firstNote = NoteModel(
        key: 60,
        velocity: 0.8,
        length: 120,
        offset: 0,
        pan: 0,
      );
      final secondNote = NoteModel(
        key: 62,
        velocity: 0.8,
        length: 120,
        offset: 200,
        pan: 0,
      );

      pattern.notes[firstNote.id] = firstNote;
      pattern.notes[secondNote.id] = secondNote;

      paintCurrentFrame(
        timeViewStart: 0,
        timeViewEnd: 1000,
        keyValueAtTop: 64,
        size: const Size(400, 200),
      );

      final renderedNoteIds = viewModel.visibleNotes
          .getAnnotations()
          .map((annotation) => annotation.metadata.id)
          .toSet();

      expect(renderedNoteIds, containsAll({firstNote.id, secondNote.id}));
    });
  });
}
