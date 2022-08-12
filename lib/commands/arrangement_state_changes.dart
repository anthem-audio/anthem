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
import 'package:freezed_annotation/freezed_annotation.dart';

part "arrangement_state_changes.freezed.dart";

@freezed
class ArrangementStateChange with _$ArrangementStateChange {
  const factory ArrangementStateChange.clipAdded(ID projectID, ID arrangementID) = ClipAdded;
  const factory ArrangementStateChange.clipDeleted(ID projectID, ID arrangementID) = ClipDeleted;
  const factory ArrangementStateChange.arrangementAdded(ID projectID, ID arrangementID) = ArrangementAdded;
  const factory ArrangementStateChange.arrangementDeleted(ID projectID, ID arrangementID) = ArrangementDeleted;
  const factory ArrangementStateChange.arrangementNameChanged(ID projectID, ID arrangementID) = ArrangementNameChanged;
}
