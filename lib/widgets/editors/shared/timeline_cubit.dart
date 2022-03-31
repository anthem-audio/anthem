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

import 'package:anthem/commands/state_changes.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../model/pattern.dart';
import '../../../model/project.dart';
import '../../../model/store.dart';
import '../../../model/time_signature.dart';

part 'timeline_state.dart';
part 'timeline_cubit.freezed.dart';

enum TimelineType {
  arrangerTimeline,
  patternTimeline,
}

class TimelineCubit extends Cubit<TimelineState> {
  final TimelineType timelineType;
  late final ProjectModel project;

  TimelineCubit({
    required this.timelineType,
    required int projectID,
  }) : super((() {
          final project = Store.instance.projects[projectID]!;

          int? patternID;
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
            timeSignatureChanges: timeSignatureChanges,
            ticksPerQuarter: project.song.ticksPerQuarter,
          );
        })()) {
    project = Store.instance.projects[projectID]!;

    if (timelineType == TimelineType.patternTimeline) {
      project.stateChangeStream
          .where((event) => event is ActivePatternSet)
          .map((event) => event as ActivePatternSet)
          .listen((event) {
        emit(state.copyWith(patternID: event.patternID));
      });
    }
  }
}
