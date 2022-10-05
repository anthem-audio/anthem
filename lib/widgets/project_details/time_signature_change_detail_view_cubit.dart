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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'time_signature_change_detail_view_state.dart';
part 'time_signature_change_detail_view_cubit.freezed.dart';

class TimeSignatureChangeDetailViewCubit
    extends Cubit<TimeSignatureChangeDetailViewState> {
  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  TimeSignatureChangeDetailViewCubit({required String projectID})
      : super(
          (() {
            String? patternID;
            String? arrangementID;

            final project = Store.instance.projects[projectID]!;

            int numerator = -1;
            int denominator = -1;

            if (project.selectedDetailView
                is TimeSignatureChangeDetailViewKind) {
              final detailView = project.selectedDetailView
                  as TimeSignatureChangeDetailViewKind;
              patternID = detailView.patternID;
              arrangementID = detailView.arrangementID;

              if (patternID != null) {
                final change = project
                    .song.patterns[patternID]!.timeSignatureChanges
                    .firstWhere(
                  (element) => element.id == detailView.changeID,
                );

                numerator = change.timeSignature.numerator;
                denominator = change.timeSignature.denominator;
              } else {
                throw UnimplementedError(
                  "Arrangements can't have time signature changes yet.",
                );
              }
            }

            return TimeSignatureChangeDetailViewState(
              projectID: projectID,
              patternID: patternID,
              arrangementID: arrangementID,
              numerator: numerator,
              denominator: denominator,
            );
          })(),
        ) {
    project = Store.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    // var didSomeItemChange = false;

    for (final change in changes) {
      // if (change is SomeChange) {
      //   didSomeItemChange = true;
      // }
    }

    TimeSignatureChangeDetailViewState? newState;

    // if (didSomeItemChange) {
    //   newState = (newState ?? state).copyWith(
    //     ...
    //   );
    // }

    if (newState != null) {
      emit(newState);
    }
  }
}
