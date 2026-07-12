/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/stem_editor_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';

export 'package:anthem/widgets/editors/piano_roll/controller/state_machine/stem_editor_state_machine.dart'
    show PianoRollStemEditorPointerEvent;

class PianoRollStemEditorController {
  final ProjectModel project;
  final PianoRollViewModel viewModel;
  late final PianoRollStemEditorStateMachine stateMachine =
      PianoRollStemEditorStateMachine.create(
        project: project,
        viewModel: viewModel,
      );
  bool _isDisposed = false;

  PianoRollStemEditorController({
    required this.project,
    required this.viewModel,
  });

  void pointerDown(PianoRollStemEditorPointerEvent event) {
    stateMachine.onPointerDown(event);
  }

  void pointerMove(PianoRollStemEditorPointerEvent event) {
    stateMachine.onPointerMove(event);
  }

  void pointerUp(PianoRollStemEditorPointerEvent event) {
    stateMachine.onPointerUp(event);
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    stateMachine.dispose();
  }
}
