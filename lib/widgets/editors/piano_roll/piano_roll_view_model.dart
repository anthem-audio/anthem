/*
  Copyright (C) 2023 Joshua Wade

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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:mobx/mobx.dart';

part 'piano_roll_view_model.g.dart';

enum NoteAttribute { velocity, pan }

// ignore: library_private_types_in_public_api
class PianoRollViewModel = _PianoRollViewModel with _$PianoRollViewModel;

abstract class _PianoRollViewModel with Store {
  _PianoRollViewModel({
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.timeView,
  });

  @observable
  double keyHeight;

  @observable
  double keyValueAtTop;

  @observable
  TimeRange timeView;

  @observable
  Rectangle<double>? selectionBox;

  @observable
  ObservableSet<ID> selectedNotes = ObservableSet();

  @observable
  ID? pressedNote;

  @observable
  NoteAttribute activeNoteAttribute = NoteAttribute.velocity;

  // These don't need to be observable, since they're just used during event
  // handling.
  Time cursorNoteLength = 96;
  int cursorNoteVelocity = 128 * 3 ~/ 4;
  int cursorNotePan = 0;
}
