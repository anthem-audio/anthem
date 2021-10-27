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

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

part 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  final Store _store = Store.instance;

  ProjectCubit({required int id})
      : super(
          ProjectState(
            id: id,
            activeInstrumentID: null,
            activeControllerID: null,
          ),
        );

  Future<void> undo() => _store.msgUndo(state.id);
  Future<void> redo() => _store.msgRedo(state.id);
  void setActiveInstrumentID(int? id) {
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: state.activeControllerID,
        activeInstrumentID: id,
      ),
    );
  }

  void setActiveControllerID(int? id) {
    emit(
      ProjectState(
        id: state.id,
        activeInstrumentID: state.activeInstrumentID,
        activeControllerID: id,
      ),
    );
  }
}
