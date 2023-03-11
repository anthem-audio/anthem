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

import 'dart:async';

import 'package:anthem/commands/pattern_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'piano_roll_state.dart';
part 'piano_roll_cubit.freezed.dart';

const noContentBars = 16;

class PianoRollCubit extends Cubit<PianoRollState> {
  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  PianoRollCubit({required ID projectID})
      : super(
          (() {
            final project = AnthemStore.instance.projects[projectID]!;

            return PianoRollState(
              projectID: projectID,
              ticksPerQuarter: project.song.ticksPerQuarter,
              keyHeight: 20,
              keyValueAtTop:
                  63.95, // Hack: cuts off the top horizontal line. Otherwise the default view looks off
              lastContent: project.song.ticksPerQuarter *
                  // TODO: Use actual project time signature
                  4 * // 4/4 time signature
                  noContentBars, // noContentBars bars
            );
          })(),
        ) {
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  _onModelChanged(List<StateChange> changes) {
    var updateActivePattern = false;
    var updateActiveGenerator = false;
    var timeMarkersChanged = false;

    void noteChangedFn(NoteStateChange change) {
      if (change.patternID == project.song.activePatternID) {
        updateActivePattern = true;
      }
    }

    for (final change in changes) {
      change.whenOrNull(
        project: (change) {
          change.mapOrNull(
            activePatternChanged: (change) {
              updateActivePattern = true;
              timeMarkersChanged = true;
            },
            activeGeneratorChanged: (change) {
              updateActivePattern = true;
              updateActiveGenerator = true;
            },
          );
        },
        note: (change) {
          change.mapOrNull(
            noteAdded: noteChangedFn,
            noteDeleted: noteChangedFn,
            noteMoved: noteChangedFn,
            noteResized: noteChangedFn,
          );
        },
        pattern: (change) {
          change.mapOrNull(
            timeSignatureChangeListUpdated: (change) {
              if (change.patternID == project.song.activePatternID) {
                timeMarkersChanged = true;
              }
            },
          );
        },
      );
    }

    PianoRollState? newState;

    if (updateActivePattern) {
      final patternID = project.song.activePatternID;
      final pattern = project.song.patterns[patternID];

      newState = (newState ?? state).copyWith(
        patternID: patternID,
        lastContent: pattern?.getWidth(
              barMultiple: 4,
              minPaddingInBarMultiples: 4,
            ) ??
            state.ticksPerQuarter * 4 * noContentBars,
      );
    }

    if (updateActiveGenerator) {
      final patternID = (newState ?? state).patternID;
      final pattern = project.song.patterns[patternID];

      newState = (newState ?? state).copyWith(
        activeInstrumentID: project.song.activeGeneratorID,
        lastContent: pattern?.getWidth(
              barMultiple: 4,
              minPaddingInBarMultiples: 4,
            ) ??
            state.ticksPerQuarter * 4 * noContentBars,
      );
    }

    if (timeMarkersChanged) {
      final timeSignatureChanges = project.song
              .patterns[project.song.activePatternID]?.timeSignatureChanges ??
          [];
      newState = (newState ?? state).copyWith(
        hasTimeMarkers: timeSignatureChanges.isNotEmpty,
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }

  void setKeyHeight(double newKeyHeight) {
    emit(state.copyWith(keyHeight: newKeyHeight));
  }

  void setKeyValueAtTop(double newKeyValueAtTop) {
    emit(state.copyWith(keyValueAtTop: newKeyValueAtTop));
  }
}
