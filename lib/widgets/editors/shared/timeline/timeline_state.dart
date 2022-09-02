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

part of 'timeline_cubit.dart';

// Hack: Wrapping this allows us to trigger re-renders in flutter more easily.
// Freezed overrides ==, but that means that cloning the list of time signature
// changes isn't enough to trigger a re-render.
class TimeSignatureChangeListWrapper {
  List<TimeSignatureChangeModel> inner;

  TimeSignatureChangeListWrapper({required this.inner});
}

@Freezed()
class TimelineState with _$TimelineState {
  factory TimelineState({
    required ID? patternID,
    required ID? arrangementID,
    required int ticksPerQuarter,
    required TimeSignatureModel defaultTimeSignature,
    required TimeSignatureChangeListWrapper timeSignatureChanges,
  }) = _TimelineState;
}
