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
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'timeline_state.dart';
part 'timeline_cubit.freezed.dart';

enum TimelineType {
  arrangerTimeline,
  patternTimeline,
}

class TimelineCubit extends Cubit<TimelineState> {
  final TimelineType timelineType;

  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  TimelineCubit({
    required this.timelineType,
    required ID projectID,
  }) : super((() {
          final project = Store.instance.projects[projectID]!;

          ID? patternID;
          PatternModel? pattern;
          var defaultTimeSignature = TimeSignatureModel(4, 4);
          List<TimeSignatureChangeModel> timeSignatureChanges = [];

          if (timelineType == TimelineType.patternTimeline) {
            patternID = project.song.activePatternID;
            pattern = project.song.patterns[patternID];
          }

          if (pattern != null) {
            defaultTimeSignature = pattern.defaultTimeSignature;
            timeSignatureChanges = pattern.timeSignatureChanges;
          }

          return TimelineState(
            patternID: patternID,
            arrangementID: null,
            defaultTimeSignature: defaultTimeSignature,
            timeSignatureChanges: TimeSignatureChangeListWrapper(
              inner: timeSignatureChanges,
            ),
            ticksPerQuarter: project.song.ticksPerQuarter,
          );
        })()) {
    project = Store.instance.projects[projectID]!;

    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  _onModelChanged(List<StateChange> changes) {
    var activePatternChanged = false;
    var timeSignatureListChanged = false;

    final isPatternTimeline = timelineType == TimelineType.patternTimeline;

    for (final change in changes) {
      bool didActivePatternChange(StateChange change) {
        return change.maybeWhen(
          project: (change) => change.maybeMap(
            activePatternChanged: (change) => true,
            orElse: () => false,
          ),
          orElse: () => false,
        );
      }

      if (isPatternTimeline && didActivePatternChange(change)) {
        activePatternChanged = true;
      }

      timeSignatureListChanged |= change.maybeWhen(
        pattern: (change) => change.maybeMap(
          timeSignatureChangeListUpdated: (change) => isPatternTimeline,
          orElse: () => false,
        ),
        orElse: () => false,
      );
    }

    TimelineState? newState;

    TimeSignatureChangeListWrapper getTimeSignatureChanges() {
      return TimeSignatureChangeListWrapper(
        inner: isPatternTimeline
            ? project.song.patterns[project.song.activePatternID]!
                .timeSignatureChanges
            // : project.song.arrangements[project.song.activeArrangementID]!
            //         .timeSignatureChanges;
            : [],
      );
    }

    if (activePatternChanged) {
      newState = (newState ?? state).copyWith(
        patternID: project.song.activePatternID,
        timeSignatureChanges: getTimeSignatureChanges(),
      );
    }

    if (timeSignatureListChanged) {
      newState = (newState ?? state).copyWith(
        timeSignatureChanges: getTimeSignatureChanges(),
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }
}
