/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/model/shared/time_signature.dart';

import 'types.dart';

const minorMinPixels = 18.0;
const majorMinPixels = minorMinPixels * 2.0;
const barMinPixels = majorMinPixels * 2.0;

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

/// Contains information about how to render and snap in a given section of
/// time.
///
/// [offset] describes where this section starts. We may have multiple sections
/// with different rendering and snapping characteristics because of time
/// signature changes. If a pattern or arrangement has no time signature
/// changes, then there will be one [DivisionChange] to describe the entire
/// pattern or arrangement.
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

  /// Number of input units (snap) skipped for each division. Sometimes this is 1, but
  /// sometimes (always when zoomed far out) this is higher.
  int distanceBetween;

  /// For bar rendering. The bar number at the beginning of the first division (?)
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
  final barLength = getBarLength(ticksPerQuarter, timeSignature);
  final divisionSizeLowerBound = ticksPerPixel * minPixelsPerDivision;

  // bestDivision starts at some small value and works up to the smallest valid
  // value
  int bestDivision;
  int snapSize;
  int skip = 1;

  switch (snap) {
    case BarSnap():
      {
        bestDivision = barLength;
        snapSize = barLength;
        break;
      }
    case DivisionSnap() || AutoSnap():
      {
        if (divisionSizeLowerBound >= barLength) {
          snapSize = barLength;
        } else {
          final division = snap is DivisionSnap
              ? snap.division
              : Division(multiplier: 1, divisor: 4);
          snapSize = division.getSizeInTicks(ticksPerQuarter, timeSignature);
        }
        bestDivision = snapSize;
        break;
      }
  }

  final numDivisionsInBar = barLength ~/ snapSize;

  if (bestDivision < barLength) {
    final multipliers = factors(numDivisionsInBar);

    for (final multiplier in multipliers) {
      if (bestDivision >= divisionSizeLowerBound) {
        return GetBestDivisionResult(
          renderSize: bestDivision,
          snapSize: snap is DivisionSnap ? snapSize : bestDivision,
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
    snapSize: snap is DivisionSnap ? snapSize : bestDivision,
    skip: skip,
  );
}

/// Takes information about the time signature changes in the current time
/// view, and returns a list of [DivisionChange] objects that describe the
/// regions within the current time view.
///
/// For example, if the [defaultTimeSignature] is 3/4 and there is a single
/// change to 4/4, this function will return two [DivisionChange] objects, one
/// describing the snapping behavior and bar lines for the initial 3/4 section
/// section, and one describing the same for the 4/4 section.
List<DivisionChange> getDivisionChanges({
  required double viewWidthInPixels,
  double minPixelsPerSection = minorMinPixels,
  required Snap snap,
  required TimeSignatureModel defaultTimeSignature,
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
  bool ceil = false,
  bool round = false,

  // This allows us to move things by snap intervals while preserving their
  // offset from the snap boundaries. Leaving this unset will cause things to
  // always clamp to the snap boundaries.
  Time startTime = 0,
}) {
  Time raw = rawTime;
  Time snapped = -1;

  for (var i = 0; i < divisionChanges.length; i++) {
    if (raw >= 0 &&
        i < divisionChanges.length - 1 &&
        divisionChanges[i + 1].offset <= raw) {
      continue;
    }

    final divisionChange = divisionChanges[i];
    final snapSize = divisionChange.divisionSnapSize;

    if (round) raw += snapSize ~/ 2;

    final startTimeCorrection = startTime % snapSize;

    snapped =
        ((raw - startTimeCorrection) ~/ snapSize) * snapSize +
        (ceil && raw % snapSize != 0 ? snapSize : 0);
    snapped += divisionChange.offset % snapSize;
    snapped += startTimeCorrection;

    break;
  }

  return snapped;
}

void zoomTimeView({
  required TimeRange timeView,
  required double delta,
  required double mouseX,
  required double editorWidth,
}) {
  final timeViewWidth = timeView.width;

  // Convert the time view width to log. Converting to log means we can
  // adjust the size by adding or subtracting a constant value, and it
  // feels right. It also means that zooming in by one tick and then
  // zooming out by one tick gets you back to the exact same position.
  final timeViewWidthLog = log(timeViewWidth);
  final newTimeViewWidthLog = timeViewWidthLog + delta * 0.0025;
  final newTimeViewWidth = pow(e, newTimeViewWidthLog);

  final timeViewSizeChange = newTimeViewWidth - timeViewWidth;

  final mouseCursorOffset = mouseX / editorWidth;

  var newStart = timeView.start - timeViewSizeChange * mouseCursorOffset;
  var newEnd = timeView.end + timeViewSizeChange * (1 - mouseCursorOffset);

  // Somewhat arbitrary, but a safeguard against zooming in too far
  if (newEnd < newStart + 10) {
    newEnd = newStart + 10;
  }

  final startOvershootCorrection = newStart < 0 ? -newStart : 0;

  newStart += startOvershootCorrection;
  newEnd += startOvershootCorrection;

  timeView.start = newStart;
  timeView.end = newEnd;
}
