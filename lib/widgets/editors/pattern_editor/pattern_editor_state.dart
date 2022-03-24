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

@freezed
class PatternEditorState with _$PatternEditorState {
  factory PatternEditorState({
    required int projectID,
    int? activePatternID,
    @Default([]) List<PatternListItem> patternList,
    @Default({}) Map<int, GeneratorListItem> instruments,
    @Default({}) Map<int, GeneratorListItem> controllers,
    @Default([]) List<int> generatorIDList,
  }) = _PatternEditorState;
}

@freezed
class PatternListItem with _$PatternListItem {
  factory PatternListItem({required int id, required String name}) =
      _PatternListItem;
}

@freezed
class GeneratorListItem with _$GeneratorListItem {
  factory GeneratorListItem({required int id}) = _GeneratorListItem;
}
