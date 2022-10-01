/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/model/shared/time_signature.dart';

import 'types.dart';

const minorMinPixels = 8.0;
const majorMinPixels = 20.0;

double timeToPixels({
  required double timeViewStart,
  required double timeViewEnd,
  required double viewPixelWidth,
  required double time,
}) {
  return (time - timeViewStart) /
      (timeViewEnd - timeViewStart) *
      viewPixelWidth;
}

double pixelsToTime({
  required double timeViewStart,
  required double timeViewEnd,
  required double viewPixelWidth,
  required double pixelOffsetFromLeft,
}) {
  final timeViewWidth = timeViewEnd - timeViewStart;
  return (pixelOffsetFromLeft / viewPixelWidth) * timeViewWidth + timeViewStart;
}

// This is ported from Rust. I don't know what I was doing, but the naming here
// is confusing. Why doesn't this contain a Division? Should it? I don't want
// to think this through now, so I'm leaving a note.

class DivisionChange {
  DivisionChange({
    required this.offset,
    required this.divisionRenderSize,
    required this.divisionSnapSize,
    required this.distanceBetween,
    required this.startLabel,
  });

  Time offset;
  Time divisionRenderSize;
  Time divisionSnapSize;

  // Number of input units (snap) skipped for each division. Sometimes this is 1, but
  // sometimes (always when zoomed far out) this is higher.
  int distanceBetween;

  // For bar rendering. The bar number at the beginning of the first division (?)
  int startLabel;
}

Time getBarLength(Time ticksPerQuarter, TimeSignatureModel? timeSignature) {
  // Fall back to 4/4 time signature
  if (timeSignature == null) {
    return ticksPerQuarter * 4;
  }

  return (ticksPerQuarter * 4 * timeSignature.numerator) ~/
      timeSignature.denominator;
}

class GetBestDivisionResult {
  GetBestDivisionResult({
    required this.renderSize,
    required this.snapSize,
    required this.skip,
  });

  Time renderSize;
  Time snapSize;
  int skip;
}

List<int> allPrimesUntil(int upper) {
  // sieve[i] represents i * 2 + 3
  List<bool> sieve = List.filled(((upper - 1) / 2).floor(), true);
  for (var i = 3; i <= upper; i += 2) {
    var sieveIndex = (i - 3) ~/ 2;
    if (!sieve[sieveIndex]) continue;

    for (var j = i * 3; j <= upper; j += i * 2) {
      sieve[(j - 3) ~/ 2] = false;
    }
  }
  List<int> result = [2];
  for (var i = 0; i < sieve.length; i++) {
    if (!sieve[i]) continue;
    result.add(i * 2 + 3);
  }
  return result;
}

// Part of this algorithm is adapted from https://github.com/wackywendell/primes
List<int> factors(int x) {
  if (x <= 1) {
    return [];
  }

  List<int> result = [];
  var curn = x;

  // hopefully quick upper-bound approximation of the number of primes we need
  // probably not fast if x is big, but x shouldn't be big
  var sqrt = 5;
  var i = 2;
  while (sqrt * sqrt < x) {
    sqrt += i;
    i += 2;
  }
  sqrt += i;

  var primes = allPrimesUntil(sqrt);

  outer:
  for (var p in primes) {
    while (curn % p == 0) {
      result.add(p);
      curn ~/= p;
      if (curn == 1) {
        return result;
      }

      if (p * p > curn) {
        break outer;
      }
    }
  }

  result.add(curn);
  return result;
}

GetBestDivisionResult getBestDivision({
  required TimeSignatureModel? timeSignature,
  required Snap snap,
  required double ticksPerPixel,
  required double minPixelsPerDivision,
  required int ticksPerQuarter,
}) {
  var barLength = getBarLength(ticksPerQuarter, timeSignature);
  var divisionSizeLowerBound = ticksPerPixel * minPixelsPerDivision;

  // bestDivision starts at some small value and works up to the smallest valid
  // value
  int bestDivision;
  int snapSize;
  int skip = 1;

  if (snap is BarSnap) {
    bestDivision = barLength;
    snapSize = barLength;
  } else if (snap is DivisionSnap) {
    if (divisionSizeLowerBound >= barLength) {
      snapSize = barLength;
    } else {
      var division = snap.division;
      snapSize = division.getSizeInTicks(ticksPerQuarter, timeSignature);
    }
    bestDivision = snapSize;
  } else {
    // This isn't TypeScript, so (I think) we can't verify completeness here.
    // If Snap gets more subclasses then this could give a runtime error.
    throw ArgumentError("Unhandled Snap type");
  }

  var numDivisionsInBar = barLength ~/ snapSize;

  if (bestDivision < barLength) {
    var multipliers = factors(numDivisionsInBar);

    for (var multiplier in multipliers) {
      if (bestDivision >= divisionSizeLowerBound) {
        return GetBestDivisionResult(
          renderSize: bestDivision,
          snapSize: snapSize,
          skip: skip,
        );
      }

      bestDivision *= multiplier;
    }
  }

  // If we got here, then bestDivision will be equal to barLength

  while (bestDivision < divisionSizeLowerBound) {
    bestDivision *= 2;
    skip *= 2;
  }

  return GetBestDivisionResult(
    renderSize: bestDivision,
    snapSize: snapSize,
    skip: skip,
  );
}

List<DivisionChange> getDivisionChanges({
  required double viewWidthInPixels,
  required double minPixelsPerSection,
  required Snap snap,
  required TimeSignatureModel? defaultTimeSignature,
  required List<TimeSignatureChangeModel> timeSignatureChanges,
  required int ticksPerQuarter,
  required double timeViewStart,
  required double timeViewEnd,
}) {
  if (viewWidthInPixels < 1) {
    return [];
  }

  List<DivisionChange> result = [];

  var startLabelPtr = 1;
  var divisionStartPtr = 0;
  var divisionBarLength = 1;

  processTimeSignatureChange(int offset, TimeSignatureModel? timeSignature) {
    var lastDivisionSize = offset - divisionStartPtr;
    startLabelPtr += lastDivisionSize ~/ divisionBarLength;
    if (lastDivisionSize % divisionBarLength > 0) {
      startLabelPtr++;
    }

    divisionStartPtr = offset;
    divisionBarLength = getBarLength(ticksPerQuarter, timeSignature);

    var bestDivision = getBestDivision(
      minPixelsPerDivision: minPixelsPerSection,
      snap: snap,
      ticksPerPixel: (timeViewEnd - timeViewStart) / viewWidthInPixels,
      ticksPerQuarter: ticksPerQuarter,
      timeSignature: timeSignature,
    );

    var nthDivision = bestDivision.skip;

    return DivisionChange(
      offset: offset,
      divisionRenderSize: bestDivision.renderSize,
      divisionSnapSize: bestDivision.snapSize,
      distanceBetween: nthDivision,
      startLabel: startLabelPtr,
    );
  }

  if (timeSignatureChanges.isEmpty || timeSignatureChanges[0].offset > 0) {
    result.add(processTimeSignatureChange(0, defaultTimeSignature));
  }

  for (var change in timeSignatureChanges) {
    result.add(processTimeSignatureChange(change.offset, change.timeSignature));
  }

  return result;
}

// Rounds the input time down to the nearest snap boundary
Time getSnappedTime({
  required Time rawTime,
  required List<DivisionChange> divisionChanges,
  bool roundUp = false,
}) {
  Time targetTime = -1;

  // A binary search might be better here, but it would only matter
  // if there were a *lot* of time signature changes in the pattern
  for (var i = 0; i < divisionChanges.length; i++) {
    if (rawTime >= 0 &&
        i < divisionChanges.length - 1 &&
        divisionChanges[i + 1].offset <= rawTime) {
      continue;
    }

    final divisionChange = divisionChanges[i];
    final snapSize = divisionChange.divisionSnapSize;
    targetTime = (rawTime ~/ snapSize) * snapSize +
        (roundUp && rawTime % snapSize != 0 ? snapSize : 0);
    targetTime += divisionChange.offset % snapSize;
    break;
  }

  return targetTime;
}
