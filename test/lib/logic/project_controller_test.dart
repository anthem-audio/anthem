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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectModel project;
  late ProjectViewModel viewModel;
  late ProjectController controller;

  setUp(() {
    project = ProjectModel.create();
    viewModel = ProjectViewModel();
    controller = ProjectController(project, viewModel);
    ServiceRegistry.initializeProject(project);
  });

  tearDown(() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  });

  group('addArrangement()', () {
    test('adds a uniquely named arrangement and activates it', () {
      final originalArrangementIds = project.sequence.arrangementOrder.toList();

      controller.addArrangement();

      expect(project.sequence.arrangementOrder, hasLength(2));

      final newArrangementId = project.sequence.arrangementOrder.last;
      final newArrangement = project.sequence.arrangements[newArrangementId];

      expect(newArrangementId, isNot(originalArrangementIds.single));
      expect(newArrangement, isNotNull);
      expect(newArrangement!.name, equals('Arrangement 2'));
      expect(project.sequence.activeArrangementID, equals(newArrangementId));
      expect(
        project.sequence.activeTransportSequenceID,
        equals(newArrangementId),
      );
    });

    test('uses provided arrangement name', () {
      controller.addArrangement('Verse');

      final arrangementId = project.sequence.arrangementOrder.last;
      expect(
        project.sequence.arrangements[arrangementId]!.name,
        equals('Verse'),
      );
    });
  });

  group('editor and transport selection', () {
    test(
      'setActiveArrangement updates active arrangement and transport id',
      () {
        controller.addArrangement('Verse');
        final arrangementId = project.sequence.arrangementOrder.last;

        controller.setActiveArrangement(arrangementId);

        expect(project.sequence.activeArrangementID, equals(arrangementId));
        expect(
          project.sequence.activeTransportSequenceID,
          equals(arrangementId),
        );
      },
    );

    test('setActivePattern updates active pattern and transport id', () {
      final pattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(project.allocateId),
        name: 'Lead',
      );
      project.sequence.patterns[pattern.id] = pattern;

      controller.setActivePattern(pattern.id);

      expect(project.sequence.activePatternID, equals(pattern.id));
      expect(project.sequence.activeTransportSequenceID, equals(pattern.id));
    });

    test('setActiveEditor maps editor selection to panel selection', () {
      controller.setActiveEditor(editor: EditorKind.detail);
      expect(viewModel.selectedEditor, equals(EditorKind.detail));
      expect(viewModel.activePanel, equals(PanelKind.pianoRoll));

      controller.setActiveEditor(editor: EditorKind.automation);
      expect(viewModel.activePanel, equals(PanelKind.automationEditor));

      controller.setActiveEditor(editor: EditorKind.channelRack);
      expect(viewModel.activePanel, equals(PanelKind.channelRack));

      controller.setActiveEditor(editor: EditorKind.mixer);
      expect(viewModel.activePanel, equals(PanelKind.mixer));
    });

    test('openPatternInPianoRoll switches editor and activates pattern', () {
      final pattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(project.allocateId),
        name: 'Bass',
      );
      project.sequence.patterns[pattern.id] = pattern;

      controller.openPatternInPianoRoll(pattern.id);

      expect(viewModel.selectedEditor, equals(EditorKind.detail));
      expect(viewModel.activePanel, equals(PanelKind.pianoRoll));
      expect(project.sequence.activePatternID, equals(pattern.id));
    });

    test('openPatternInPianoRoll is a no-op for a missing pattern', () {
      viewModel.selectedEditor = EditorKind.mixer;
      viewModel.activePanel = PanelKind.mixer;
      project.sequence.activePatternID = null;

      controller.openPatternInPianoRoll(-1);

      expect(viewModel.selectedEditor, equals(EditorKind.mixer));
      expect(viewModel.activePanel, equals(PanelKind.mixer));
      expect(project.sequence.activePatternID, isNull);
    });
  });
}
