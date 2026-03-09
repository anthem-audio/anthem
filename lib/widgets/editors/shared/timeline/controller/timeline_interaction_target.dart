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
import 'package:anthem/logic/commands/timeline_commands.dart';

/// Identifies which shared timeline target is being edited.
///
/// This first scaffold keeps the target passive. Later migration steps can add
/// model lookup and mutation helpers once the controller owns live behavior.
class TimelineInteractionTarget {
  final TimelineKind kind;
  final Id sequenceId;
  final Id? arrangementID;
  final Id? patternID;

  const TimelineInteractionTarget._({
    required this.kind,
    required this.sequenceId,
    required this.arrangementID,
    required this.patternID,
  });

  bool get isArrangement => kind == TimelineKind.arrangement;
  bool get isPattern => kind == TimelineKind.pattern;

  static TimelineInteractionTarget? tryCreate({
    required Id? arrangementID,
    required Id? patternID,
  }) {
    assert(
      arrangementID == null || patternID == null,
      'TimelineInteractionTarget can target at most one sequence at a time.',
    );

    if (patternID != null) {
      return TimelineInteractionTarget._(
        kind: TimelineKind.pattern,
        sequenceId: patternID,
        arrangementID: null,
        patternID: patternID,
      );
    }

    if (arrangementID != null) {
      return TimelineInteractionTarget._(
        kind: TimelineKind.arrangement,
        sequenceId: arrangementID,
        arrangementID: arrangementID,
        patternID: null,
      );
    }

    return null;
  }
}
