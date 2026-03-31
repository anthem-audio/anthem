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

class StickyDragResult {
  final double rawValue;
  final bool changed;

  const StickyDragResult({required this.rawValue, required this.changed});
}

/// A controller that applies sticky-point trapping and edge overshoot to a
/// normalized drag value.
///
/// The controller operates entirely in `0.0..1.0` space. Call [reset] when a
/// drag starts, then pass each drag update to [applyRawDelta] as a change in
/// normalized raw units rather than pixels or the control's external value
/// range.
///
/// The controller keeps the current raw value and the temporary state needed
/// to snap to sticky points, require extra movement to break out of them, and
/// remember motion that continues past either end of the range. Widgets are
/// expected to convert their own domain values to and from normalized values
/// before calling into it.
class StickyDragController {
  final double stickyTrapSize;

  double _rawValue = 0;
  double _pastStart = 0;
  double _pastEnd = 0;
  double? _stickyTrapCounter;
  List<double> _stickyPoints = const [];

  StickyDragController({required this.stickyTrapSize})
    : assert(stickyTrapSize >= 0);

  double get rawValue => _rawValue;

  void reset({required double rawValue, required List<double> stickyPoints}) {
    _rawValue = rawValue.clamp(0.0, 1.0).toDouble();
    _stickyPoints = stickyPoints;
    _pastStart = 0;
    _pastEnd = 0;
    _stickyTrapCounter = null;
  }

  StickyDragResult applyRawDelta(double rawDelta) {
    var remainingDelta = rawDelta;
    var allowStickyCapture = true;
    final startingRawValue = _rawValue;

    final stickyTrapCounter = _stickyTrapCounter;
    if (stickyTrapCounter != null) {
      final updatedStickyTrapCounter = stickyTrapCounter + remainingDelta;

      if (updatedStickyTrapCounter.abs() <= stickyTrapSize) {
        _stickyTrapCounter = updatedStickyTrapCounter;
        return StickyDragResult(rawValue: _rawValue, changed: false);
      }

      remainingDelta = updatedStickyTrapCounter > 0
          ? updatedStickyTrapCounter - stickyTrapSize
          : updatedStickyTrapCounter + stickyTrapSize;
      _stickyTrapCounter = null;
      allowStickyCapture = false;
    }

    remainingDelta = _consumeExistingBoundaryOvershoot(remainingDelta);
    if (remainingDelta == 0) {
      return StickyDragResult(rawValue: _rawValue, changed: false);
    }

    final candidateRawValue = _rawValue + remainingDelta;
    final clampedCandidateRawValue = candidateRawValue
        .clamp(0.0, 1.0)
        .toDouble();

    if (allowStickyCapture) {
      final stickyPoint = _findCrossedStickyPoint(
        start: _rawValue,
        end: clampedCandidateRawValue,
      );

      if (stickyPoint != null) {
        _rawValue = stickyPoint;
        _pastStart = 0;
        _pastEnd = 0;
        _stickyTrapCounter = remainingDelta > 0
            ? -stickyTrapSize
            : stickyTrapSize;

        return StickyDragResult(
          rawValue: _rawValue,
          changed: _rawValue != startingRawValue,
        );
      }
    }

    if (candidateRawValue < 0) {
      _rawValue = 0;
      _pastStart += candidateRawValue;
    } else if (candidateRawValue > 1) {
      _rawValue = 1;
      _pastEnd += candidateRawValue - 1;
    } else {
      _rawValue = candidateRawValue;
    }

    return StickyDragResult(
      rawValue: _rawValue,
      changed: _rawValue != startingRawValue,
    );
  }

  double _consumeExistingBoundaryOvershoot(double rawDelta) {
    var remainingDelta = rawDelta;

    if (_pastStart < 0) {
      _pastStart += remainingDelta;

      if (_pastStart > 0) {
        remainingDelta = _pastStart;
        _pastStart = 0;
      } else {
        return 0;
      }
    }

    if (_pastEnd > 0) {
      _pastEnd += remainingDelta;

      if (_pastEnd < 0) {
        remainingDelta = _pastEnd;
        _pastEnd = 0;
      } else {
        return 0;
      }
    }

    return remainingDelta;
  }

  double? _findCrossedStickyPoint({
    required double start,
    required double end,
  }) {
    for (final stickyPoint in _stickyPoints) {
      if (start < stickyPoint && end >= stickyPoint) {
        return stickyPoint;
      }

      if (start > stickyPoint && end <= stickyPoint) {
        return stickyPoint;
      }
    }

    return null;
  }
}
