/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

// This module contains the UI portion of Anthem's machinery for streaming live
// data values (e.g. CPU usage, meter levels, transport position) from the
// engine to the UI. It provides a subscription model for the UI to request
// updates for specific data values.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart'
    show
        VisualizationSubscriptionSpec,
        VisualizationUpdateEvent,
        VisualizationValueType;
import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/src/visualization_transport_stats.dart';
import 'package:flutter/scheduler.dart';

part 'visualization_provider.dart';
part 'visualization_subscription.dart';

/// A visualization value paired with the engine time it represents.
class TimedVisualizationValue<T> {
  final T value;
  final Duration engineTime;

  const TimedVisualizationValue({
    required this.value,
    required this.engineTime,
  });
}

/// Closed type token that bridges a Dart payload type to the visualization wire
/// type shared with the engine.
abstract class VisualizationType<T> {
  final VisualizationValueType wireType;
  final T defaultValue;

  const VisualizationType({required this.wireType, required this.defaultValue});

  T cast(Object value);
}

class _DoubleVisualizationType extends VisualizationType<double> {
  const _DoubleVisualizationType()
    : super(wireType: VisualizationValueType.doubleValue, defaultValue: 0.0);

  @override
  double cast(Object value) {
    if (value is! double) {
      throw ArgumentError(
        'Unexpected visualization value type: ${value.runtimeType}. Expected double.',
      );
    }

    return value;
  }
}

class _IntVisualizationType extends VisualizationType<int> {
  const _IntVisualizationType()
    : super(wireType: VisualizationValueType.intValue, defaultValue: 0);

  @override
  int cast(Object value) {
    if (value is! int) {
      throw ArgumentError(
        'Unexpected visualization value type: ${value.runtimeType}. Expected int.',
      );
    }

    return value;
  }
}

class _StringVisualizationType extends VisualizationType<String> {
  const _StringVisualizationType()
    : super(wireType: VisualizationValueType.stringValue, defaultValue: '');

  @override
  String cast(Object value) {
    if (value is! String) {
      throw ArgumentError(
        'Unexpected visualization value type: ${value.runtimeType}. Expected String.',
      );
    }

    return value;
  }
}

const VisualizationType<double> doubleVisualizationType =
    _DoubleVisualizationType();
const VisualizationType<int> intVisualizationType = _IntVisualizationType();
const VisualizationType<String> stringVisualizationType =
    _StringVisualizationType();
