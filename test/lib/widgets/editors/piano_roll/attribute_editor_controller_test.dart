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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/piano_roll/attribute_editor_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
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

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttributeEditorController', () {
    late ProjectModel project;
    late PatternModel pattern;
    late PianoRollViewModel viewModel;
    late AttributeEditorController controller;
    late NoteModel note;

    setUp(() {
      project = ProjectModel.create()..engine = _StoppedEngine();
      pattern = PatternModel(idAllocator: _testIdAllocator(), name: 'Pattern');
      project.sequence.patterns[pattern.id] = pattern;
      project.sequence.activePatternID = pattern.id;
      project.sequence.activeTrackID = null;

      note = NoteModel(
        idAllocator: _testIdAllocator(),
        key: 60,
        velocity: 0.8,
        length: 96,
        offset: 120,
        pan: 0,
      );
      pattern.notes[note.id] = note;

      viewModel = PianoRollViewModel(
        keyHeight: 14,
        keyValueAtTop: 63.95,
        timeView: TimeRange(0, 3072),
      );
      controller = AttributeEditorController(viewModel: viewModel);

      final store = AnthemStore.instance;
      store.projects[project.id] = project;
      store.projectOrder.add(project.id);
      store.activeProjectId = project.id;
    });

    tearDown(() {
      final store = AnthemStore.instance;
      store.projects.remove(project.id);
      store.projectOrder.remove(project.id);
      if (store.activeProjectId == project.id) {
        store.activeProjectId = '';
      }
    });

    test('uses pattern overrides until pointerUp commits the command', () {
      const event = AttributeEditorPointerEvent(
        offset: 120,
        normalizedY: 0.25,
        viewSize: Size(960, 120),
      );

      controller.pointerMove(event);

      expect(note.velocity, equals(0.8));
      expect(pattern.noteOverrides[note.id], isNotNull);
      expect(pattern.noteOverrides[note.id]!.velocity, equals(0.25));
      expect(viewModel.cursorNoteVelocity, equals(0.25));

      controller.pointerUp(event);

      expect(note.velocity, equals(0.25));
      expect(pattern.noteOverrides, isEmpty);

      project.undo();
      expect(note.velocity, equals(0.8));
    });
  });
}
