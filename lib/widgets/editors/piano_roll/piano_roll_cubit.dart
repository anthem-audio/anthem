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

part 'piano_roll_state.dart';

class PianoRollCubit extends Cubit<PianoRollState> {
  PianoRollCubit({required int projectID})
      : super(
          PianoRollState(
            pattern: null,
            ticksPerQuarter: Store.instance.projects
                .firstWhere((project) => project.id == projectID)
                .song
                .ticksPerQuarter,
            channelID: null,
          ),
        ) {}
}
