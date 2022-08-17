/*
  Copyright (C) 2022 Joshua Wade

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
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pattern_state_changes.freezed.dart';

@freezed
class GeneratorStateChange with _$GeneratorStateChange {
  const factory GeneratorStateChange.generatorAdded(ID projectID, ID generatorID) = GeneratorAdded;
  const factory GeneratorStateChange.generatorRemoved(ID projectID, ID generatorID) = GeneratorRemoved;
}

@freezed
class PatternStateChange with _$PatternStateChange {
  const factory PatternStateChange.patternAdded(ID projectID, ID patternID) = PatternAdded;
  const factory PatternStateChange.patternDeleted(ID projectID, ID patternID) = PatternDeleted;
  const factory PatternStateChange.patternNameChanged(ID projectID, ID patternID) = PatternNameChanged;
  const factory PatternStateChange.patternColorChanged(ID projectID, ID patternID) = PatternColorChanged;
  const factory PatternStateChange.timeSignatureChangeListUpdated(ID projectID, ID patternID) = TimeSignatureChangeListUpdated;
}

@freezed
class NoteStateChange with _$NoteStateChange {
  const factory NoteStateChange.noteAdded(ID projectID, ID patternID, ID generatorID, ID noteID) = NoteAdded;
  const factory NoteStateChange.noteDeleted(ID projectID, ID patternID, ID generatorID, ID noteID) = NoteDeleted;
  const factory NoteStateChange.noteMoved(ID projectID, ID patternID, ID generatorID, ID noteID) = NoteMoved;
  const factory NoteStateChange.noteResized(ID projectID, ID patternID, ID generatorID, ID noteID) = NoteResized;
}
