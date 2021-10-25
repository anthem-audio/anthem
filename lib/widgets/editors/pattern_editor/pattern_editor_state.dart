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
  late final Pattern? pattern;
  late final List<PatternListItem> patternList;
  late final HashMap<int, Instrument> instruments;
  late final HashMap<int, Controller> controllers;
  late final List<int> generatorIDList;

  PatternEditorState({
    required this.projectID,
    required this.pattern,
    required this.patternList,
    required this.instruments,
    required this.controllers,
    required this.generatorIDList,
  });

  PatternEditorState.init(int projectID) {
    this.projectID = projectID;
    this.pattern = null;
    this.patternList = [];
    this.instruments = HashMap();
    this.controllers = HashMap();
    this.generatorIDList = [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternEditorState &&
          other.pattern == pattern &&
          other.projectID == projectID &&
          other.patternList == patternList &&
          other.instruments == instruments &&
          other.controllers == controllers &&
          other.generatorIDList == generatorIDList;
}

@immutable
class PatternListItem {
  final int id;
  final String name;

  PatternListItem({required this.id, required this.name});
}
