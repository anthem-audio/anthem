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
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';

const automationPointHoveredSizeMultiplier = 1.6;
const automationPointPressedSizeMultiplier = 1.3;

/// Tracks the animation state for an automation point.
class AutomationPointAnimationValue {
  DateTime lastUpdated = DateTime.now();
  double start;
  late double current;
  double target;
  ID pointId;
  HandleKind handleKind;

  /// Determines how fast the value will approach the target.
  ///
  /// This value should be between 0 and 1, where 0 is stopped and 1 is instant.
  double speedFactor;

  /// Checks if the current value has moved at least 99.5% of the way to the
  /// target.
  bool get isStopped => ((target - current) / (target - start)).abs() < 0.005;

  AutomationPointAnimationValue({
    required this.start,
    required this.target,
    this.speedFactor = 0.3,
    required this.pointId,
    required this.handleKind,
  }) {
    current = start;
  }

  /// Updates the animation value with the given elapesd time.
  void update(DateTime currentTime) {
    final delta = currentTime.difference(lastUpdated);
    // High framerates don't cause this to break, since we use a time duration
    // to determine how much to animate. This is just a way for me to reason
    // about the math for this algorithm. If there's a high framerate (> 60),
    // framesElapsed will be equal to less than 1 on average, and low framerates
    // will mean framesElapsed is greater than 1 on average.
    const millisecondsPerFrame = 1000.0 / 60.0;
    final framesElapsed = delta.inMilliseconds / millisecondsPerFrame;

    final distanceToTarget = target - current;

    final newDistanceToTarget =
        distanceToTarget * pow(1 - speedFactor, framesElapsed);

    current = target - newDistanceToTarget;
    lastUpdated = currentTime;
  }
}

/// Tracks the animation state for automation points.
///
/// This class is meant to be used as a generic way to track state for the hover
/// and press animations of automation points and tension handles. We want to
/// animate these in the automation editor, but also in clips, so we need a
/// generic way to track this animation state that can be tied to either the
/// automation editor or the arranger.
class AutomationPointAnimationTracker {
  final values =
      <({ID id, HandleKind handleKind}), AutomationPointAnimationValue>{};

  /// Adds a value to be tracked.
  void addValue({
    required ID id,
    required HandleKind handleKind,
    required AutomationPointAnimationValue value,
  }) =>
      values[(
        id: id,
        handleKind: handleKind,
      )] = value;

  /// Updates the values for all points that are currently animating.
  void update() {
    final currentTime = DateTime.now();

    for (final value in values.values) {
      value.update(currentTime);
    }

    values.removeWhere((key, value) => value.isStopped);
  }

  /// This value is true if there are values that are currently animating, and
  /// is false otherwise.
  bool get isActive => values.isNotEmpty;
}
