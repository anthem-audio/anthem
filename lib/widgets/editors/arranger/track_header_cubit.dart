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

import 'package:anthem/helpers/id.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../model/store.dart';

part 'track_header_state.dart';
part 'track_header_cubit.freezed.dart';

class TrackHeaderCubit extends Cubit<TrackHeaderState> {
  TrackHeaderCubit({
    required ID projectID,
    required ID trackID,
  }) : super((() {
          final project = AnthemStore.instance.projects[projectID]!;

          return TrackHeaderState(
            projectID: projectID,
            trackID: trackID,
            trackName: project.song.tracks[trackID]!.name,
          );
        })());
}
