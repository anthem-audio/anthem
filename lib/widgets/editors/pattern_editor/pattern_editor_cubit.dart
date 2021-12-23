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

import 'dart:async';
import 'dart:collection';

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/project_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:optional/optional.dart';

part 'pattern_editor_state.dart';

class PatternEditorCubit extends Cubit<PatternEditorState> {
  // ignore: unused_field
  late final StreamSubscription<ActivePatternSet> _updateActivePatternSub;
  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _updatePatternListSub;
  // ignore: unused_field
  late final StreamSubscription<GeneratorStateChange> _updateGeneratorListSub;

  final ProjectModel project;

  PatternEditorCubit({required this.project})
      : super(PatternEditorState.init(project.id)) {
    _updateActivePatternSub = project.stateChangeStream
        .where((change) => change is ActivePatternSet)
        .map((change) => change as ActivePatternSet)
        .listen(_updateActivePattern);
    _updatePatternListSub = project.stateChangeStream
        .where((change) => change is PatternAdded || change is PatternDeleted)
        .map((change) => change as PatternStateChange)
        .listen(_updatePatternList);
    _updateGeneratorListSub = project.stateChangeStream
        .where(
            (change) => change is GeneratorAdded || change is GeneratorRemoved)
        .map((change) => change as GeneratorStateChange)
        .listen(_updateGeneratorList);
  }

  _updateActivePattern(ActivePatternSet change) {
    emit(state.copyWith(
        activePattern: Optional.ofNullable(
            project.song.patterns[project.song.activePatternID])));
  }

  _updatePatternList(PatternStateChange _reply) {
    emit(state.copyWith(
        patternList: project.song.patternOrder
            .map(
              (id) => PatternListItem(
                  id: id, name: project.song.patterns[id]?.name ?? ""),
            )
            .toList()));
  }

  _updateGeneratorList(GeneratorStateChange _reply) {
    emit(state.copyWith(
      controllers: project.controllers
          .map((key, value) => MapEntry(key, GeneratorListItem(id: value.id))),
      generatorIDList: project.generatorList,
      instruments: project.instruments
          .map((key, value) => MapEntry(key, GeneratorListItem(id: value.id))),
    ));
  }

  void addPattern(String name) {
    project.execute(AddPatternCommand(
      project: project,
      pattern: PatternModel(name),
      index: project.song.patternOrder.length,
    ));
  }

  void deletePattern(int patternID) {
    project.execute(DeletePatternCommand(
      project: project,
      pattern: project.song.patterns[patternID]!,
      index: project.song.patternOrder.indexOf(patternID),
    ));
  }

  void addInstrument(String name, Color color) {
    project.execute(AddInstrumentCommand(
      project: project,
      instrumentID: getID(),
      name: name,
      color: color,
    ));
  }

  void addController(String name, Color color) {
    project.execute(AddControllerCommand(
      project: project,
      controllerID: getID(),
      name: name,
      color: color,
    ));
  }

  void removeGenerator(int id) {
    throw UnimplementedError();
  }

  void setActivePattern(int id) {
    project.song.setActivePattern(id);
  }
}
