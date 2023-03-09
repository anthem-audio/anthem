/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/commands/pattern_state_changes.dart';
import 'package:anthem/commands/project_state_changes.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'arrangement_state_changes.dart';

part 'state_changes.freezed.dart';

@freezed
class StateChange with _$StateChange {
  const factory StateChange.project(ProjectStateChange details) =
      ProjectChangeUnionType;
  const factory StateChange.arrangement(ArrangementStateChange details) =
      ArrangementChangeUnionType;
  const factory StateChange.generator(GeneratorStateChange details) =
      GeneratorChangeUnionType;
  const factory StateChange.pattern(PatternStateChange details) =
      PatternChangeUnionType;
  const factory StateChange.note(NoteStateChange details) = NoteChangeUnionType;
}
