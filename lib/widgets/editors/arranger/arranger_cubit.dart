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

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../model/store.dart';

part 'arranger_state.dart';
part 'arranger_cubit.freezed.dart';

class ArrangerCubit extends Cubit<ArrangerState> {
  ArrangerCubit({required int projectID})
      : super((() {
          final project = Store.instance.projects[projectID]!;
          return ArrangerState(
            projectID: projectID,
            activeArrangementID: project.song.activeArrangementID,
            trackIDs: project.song.arrangementOrder,
          );
        })());
}
