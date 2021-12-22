/*
  Copyright (C) 2021 Joshua Wade

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

@immutable
class PatternEditorState {
  late final int projectID;
  late final Optional<PatternModel> activePattern;
  late final List<PatternListItem> patternList;
  late final Map<int, GeneratorListItem> instruments;
  late final Map<int, GeneratorListItem> controllers;
  late final List<int> generatorIDList;

  // TODO: Figure out how to do this without late final fields
  // ignore: prefer_const_constructors_in_immutables
  PatternEditorState({
    required this.projectID,
    required this.activePattern,
    required this.patternList,
    required this.instruments,
    required this.controllers,
    required this.generatorIDList,
  });

  PatternEditorState.init(this.projectID) {
    activePattern = const Optional.empty();
    patternList = [];
    instruments = HashMap();
    controllers = HashMap();
    generatorIDList = [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternEditorState &&
          other.activePattern == activePattern &&
          other.projectID == projectID &&
          other.patternList == patternList &&
          other.instruments == instruments &&
          other.controllers == controllers &&
          other.generatorIDList == generatorIDList;

  @override
  int get hashCode =>
      activePattern.hashCode ^
      projectID.hashCode ^
      patternList.hashCode ^
      instruments.hashCode ^
      controllers.hashCode ^
      generatorIDList.hashCode;

  PatternEditorState copyWith({
    int? projectID,
    Optional<PatternModel>? activePattern,
    List<PatternListItem>? patternList,
    Map<int, GeneratorListItem>? instruments,
    Map<int, GeneratorListItem>? controllers,
    List<int>? generatorIDList,
  }) {
    return PatternEditorState(
      projectID: projectID ?? this.projectID,
      activePattern: activePattern ?? this.activePattern,
      patternList: patternList ?? this.patternList,
      instruments: instruments ?? this.instruments,
      controllers: controllers ?? this.controllers,
      generatorIDList: generatorIDList ?? this.generatorIDList,
    );
  }
}

@immutable
class PatternListItem {
  final int id;
  final String name;

  const PatternListItem({required this.id, required this.name});
}

@immutable
class GeneratorListItem {
  final int id;

  const GeneratorListItem({required this.id});
}
