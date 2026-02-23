/*
  Copyright (C) 2026 Joshua Wade

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

part of 'arranger_state_machine.dart';

/// Computes a snapped drag delta measured from [startTime].
///
/// This picks the nearest snapped point along the drag path in the active
/// drag direction. The drag start is treated as the center of the initial snap
/// region, so the first movement threshold is half a snap interval.
///
/// Snap interval size is resolved from [divisionChanges] at the current
/// absolute traversal position, so this adapts when crossing time-division
/// boundaries.
int getSnappedDragDelta({
  required int startTime,
  required int currentTime,
  required List<DivisionChange> divisionChanges,
}) {
  final rawDelta = currentTime - startTime;
  if (rawDelta == 0) {
    return 0;
  }

  final direction = rawDelta.sign;
  var nearerDelta = 0;
  var fartherDelta = _stepSnappedDragDelta(
    startTime: startTime,
    snappedDelta: nearerDelta,
    direction: direction,
    divisionChanges: divisionChanges,
  );

  while ((direction > 0 && fartherDelta < rawDelta) ||
      (direction < 0 && fartherDelta > rawDelta)) {
    nearerDelta = fartherDelta;
    fartherDelta = _stepSnappedDragDelta(
      startTime: startTime,
      snappedDelta: nearerDelta,
      direction: direction,
      divisionChanges: divisionChanges,
    );
  }

  final distanceToNearer = (rawDelta - nearerDelta).abs();
  final distanceToFarther = (fartherDelta - rawDelta).abs();
  if (distanceToFarther <= distanceToNearer) {
    return fartherDelta;
  }

  return nearerDelta;
}

/// Steps a snapped drag delta one snapped interval toward zero.
///
/// This is used for guarded behaviors (e.g. resizing) where we need to retreat
/// one valid snapped increment at a time.
int stepSnappedDragDeltaTowardZero({
  required int startTime,
  required int snappedDelta,
  required List<DivisionChange> divisionChanges,
}) {
  if (snappedDelta == 0) {
    return 0;
  }

  final direction = snappedDelta > 0 ? -1 : 1;
  final nextDelta = _stepSnappedDragDelta(
    startTime: startTime,
    snappedDelta: snappedDelta,
    direction: direction,
    divisionChanges: divisionChanges,
  );

  if ((snappedDelta > 0 && nextDelta < 0) ||
      (snappedDelta < 0 && nextDelta > 0)) {
    return 0;
  }

  return nextDelta;
}

int _stepSnappedDragDelta({
  required int startTime,
  required int snappedDelta,
  required int direction,
  required List<DivisionChange> divisionChanges,
}) {
  assert(direction == -1 || direction == 1);

  final cursor = startTime + snappedDelta;
  if (direction > 0) {
    final step = _getSnapSizeAtAbsoluteTime(
      absoluteTime: cursor,
      divisionChanges: divisionChanges,
    );
    return snappedDelta + step;
  }

  final step = _getSnapSizeAtAbsoluteTime(
    absoluteTime: cursor - 1,
    divisionChanges: divisionChanges,
  );
  return snappedDelta - step;
}

int _getSnapSizeAtAbsoluteTime({
  required int absoluteTime,
  required List<DivisionChange> divisionChanges,
}) {
  if (divisionChanges.isEmpty) {
    return 1;
  }

  for (var i = 0; i < divisionChanges.length; i++) {
    if (absoluteTime >= 0 &&
        i < divisionChanges.length - 1 &&
        divisionChanges[i + 1].offset <= absoluteTime) {
      continue;
    }

    return max(1, divisionChanges[i].divisionSnapSize);
  }

  return max(1, divisionChanges.last.divisionSnapSize);
}
