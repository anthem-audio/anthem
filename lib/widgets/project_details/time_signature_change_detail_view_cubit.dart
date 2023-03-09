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
import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
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
            ID? patternID;
            ID? arrangementID;

            final project = AnthemStore.instance.projects[projectID]!;

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
            } else {
              throw StateError(
                "Tried to create a TimeSignatureChangeDetailViewCubit, but the active detail view kind isn't a TimeSignatureChangeDetailView.",
              );
            }

            return TimeSignatureChangeDetailViewState(
              projectID: projectID,
              patternID: patternID,
              arrangementID: arrangementID,
              changeID: (project.selectedDetailView
                      as TimeSignatureChangeDetailViewKind)
                  .changeID,
              numerator: numerator,
              denominator: denominator,
            );
          })(),
        ) {
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var timeSignatureListChanged = false;

    for (final change in changes) {
      change.whenOrNull(
        arrangement: (change) {
          return; // TODO: handle arrangement time signature changes
        },
        pattern: (change) {
          change.mapOrNull(timeSignatureChangeListUpdated: (change) {
            if (state.patternID == change.patternID) {
              timeSignatureListChanged = true;
            }
          });
        },
      );
    }

    TimeSignatureChangeDetailViewState? newState;

    ArrangementModel? arrangement;
    PatternModel? pattern;

    if (state.arrangementID != null) {
      arrangement = project.song.arrangements[state.arrangementID]!;
    }

    if (state.patternID != null) {
      pattern = project.song.patterns[state.patternID]!;
    }

    if (timeSignatureListChanged) {
      if (state.patternID != null) {
        final timeSignatureChange = arrangement != null
            ? (throw UnimplementedError())
            : pattern!.timeSignatureChanges.firstWhere(
                (change) => change.id == state.changeID,
              );

        newState = (newState ?? state).copyWith(
          numerator: timeSignatureChange.timeSignature.numerator,
          denominator: timeSignatureChange.timeSignature.denominator,
        );
      }
    }

    if (newState != null) {
      emit(newState);
    }
  }

  void setNumerator(int numerator) {
    project.execute(
      SetTimeSignatureNumeratorCommand(
        project: project,
        patternID: state.patternID,
        arrangementID: state.arrangementID,
        timelineKind: TimelineKind.pattern,
        changeID: state.changeID,
        numerator: numerator,
      ),
    );
  }

  void setDenominator(int denominator) {
    project.execute(
      SetTimeSignatureDenominatorCommand(
        project: project,
        patternID: state.patternID,
        arrangementID: state.arrangementID,
        timelineKind: TimelineKind.pattern,
        changeID: state.changeID,
        denominator: denominator,
      ),
    );
  }
}
