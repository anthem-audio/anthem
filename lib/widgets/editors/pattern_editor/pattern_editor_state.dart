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

part of 'pattern_editor_cubit.dart';

// Workaround for https://github.com/rrousselGit/freezed/issues/653
@Freezed(makeCollectionsUnmodifiable: false)
class PatternEditorState with _$PatternEditorState {
  factory PatternEditorState({
    required ID projectID,
    ID? activePatternID,
    @Default([]) List<PatternListItem> patternList,
    @Default({}) Map<ID, GeneratorListItem> instruments,
    @Default({}) Map<ID, GeneratorListItem> controllers,
    @Default([]) List<ID> generatorIDList,
  }) = _PatternEditorState;
}

// Workaround for https://github.com/rrousselGit/freezed/issues/653
@Freezed(makeCollectionsUnmodifiable: false)
class PatternListItem with _$PatternListItem {
  factory PatternListItem({required ID id, required String name}) =
      _PatternListItem;
}

// Workaround for https://github.com/rrousselGit/freezed/issues/653
@Freezed(makeCollectionsUnmodifiable: false)
class GeneratorListItem with _$GeneratorListItem {
  factory GeneratorListItem({required ID id}) = _GeneratorListItem;
}
