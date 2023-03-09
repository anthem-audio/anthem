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

import 'dart:async';

import 'package:anthem/commands/arrangement_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'arrangement_detail_view_state.dart';
part 'arrangement_detail_view_cubit.freezed.dart';

class ArrangementDetailViewCubit extends Cubit<ArrangementDetailViewState> {
  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  ArrangementDetailViewCubit({
    required String projectID,
  }) : super(
          (() {
            String? arrangementID;
            final project = AnthemStore.instance.projects[projectID]!;
            if (project.selectedDetailView is ArrangementDetailViewKind) {
              arrangementID =
                  (project.selectedDetailView as ArrangementDetailViewKind)
                      .arrangementID;
            }

            return ArrangementDetailViewState(
              projectID: projectID,
              arrangementID: arrangementID,
              arrangementName:
                  project.song.arrangements[arrangementID]?.name ?? "",
            );
          })(),
        ) {
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var didNameChange = false;
    var didActiveDetailViewChange = false;

    for (final change in changes) {
      change.whenOrNull(
        arrangement: (arrangementChange) {
          arrangementChange.mapOrNull(
            arrangementNameChanged: (change) {
              if (change.arrangementID == state.arrangementID) {
                didNameChange = true;
              }
            },
          );
        },
        project: (projectChange) {
          projectChange.mapOrNull(selectedDetailViewChanged: (change) {
            didActiveDetailViewChange = true;
          });
        },
      );
    }

    ArrangementDetailViewState? newState;

    if (didActiveDetailViewChange &&
        project.selectedDetailView is ArrangementDetailViewKind) {
      final arrangementID =
          (project.selectedDetailView as ArrangementDetailViewKind)
              .arrangementID;

      emit(
        ArrangementDetailViewState(
          projectID: project.id,
          arrangementID: arrangementID,
          arrangementName: project.song.arrangements[arrangementID]!.name,
        ),
      );

      return;
    }

    if (didNameChange) {
      newState = (newState ?? state).copyWith(
        arrangementName: project.song.arrangements[state.arrangementID]!.name,
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }

  void setArrangementName(String name) {
    if (state.arrangementID == null) return;

    project.execute(
      SetArrangementNameCommand(
        project: project,
        arrangementID: state.arrangementID!,
        newName: name,
      ),
    );
  }
}
