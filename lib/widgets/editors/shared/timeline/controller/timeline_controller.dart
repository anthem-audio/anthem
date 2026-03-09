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
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';

import 'state_machine/timeline_state_machine.dart';
import 'timeline_interaction_target.dart';

/// The timeline controller, which owns logic for the timeline widget.
///
/// The current migration step establishes controller ownership of the timeline
/// state machine, while leaving live gesture handling on the legacy
/// widget-owned path in `timeline.dart`.
class TimelineController {
  final ProjectModel project;
  final Id? arrangementID;
  final Id? patternID;
  final TimelineInteractionTarget? interactionTarget;

  late final TimelineStateMachine stateMachine;

  bool _isDisposed = false;

  TimelineController({
    required this.project,
    required this.arrangementID,
    required this.patternID,
  }) : interactionTarget = TimelineInteractionTarget.tryCreate(
         arrangementID: arrangementID,
         patternID: patternID,
       ),
       assert(
         arrangementID == null || patternID == null,
         'TimelineController can target at most one sequence at a time.',
       ) {
    stateMachine = TimelineStateMachine.create(
      project: project,
      controller: this,
    );
  }

  Id? get sequenceId => interactionTarget?.sequenceId;

  @visibleForTesting
  bool get isDisposed => _isDisposed;

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    stateMachine.dispose();
  }
}
