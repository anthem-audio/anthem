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

import 'dart:collection';

import 'package:anthem/helpers/id.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'screen_overlay_state.dart';
part 'screen_overlay_cubit.freezed.dart';

class ScreenOverlayEntry {
  Widget Function(BuildContext) builder;

  ScreenOverlayEntry({required this.builder});
}

class ScreenOverlayCubit extends Cubit<ScreenOverlayState> {
  ScreenOverlayCubit() : super(ScreenOverlayState());

  void add(ID id, ScreenOverlayEntry entry) {
    emit(state.copyWith(entries: {...state.entries, id: entry}));
  }

  void remove(ID id) {
    final entries = {...state.entries};
    entries.removeWhere((entryID, entry) => entryID == id);
    emit(
      state.copyWith(
        entries: entries,
      ),
    );
  }

  void clear() {
    emit(state.copyWith(entries: {}));
  }
}
