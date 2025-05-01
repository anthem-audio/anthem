/*
  Copyright (C) 2025 Joshua Wade

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

part of 'visualization.dart';

enum VisualizationSubscriptionType { latest, max, lastNValues }

/// Represents the configuration for a visualization subscription.
class VisualizationSubscriptionConfig {
  final String id;
  final VisualizationSubscriptionType type;
  final int? bufferSize;

  /// Subscribe to the most recent value for this visualization item.
  const VisualizationSubscriptionConfig.latest(this.id)
    : type = VisualizationSubscriptionType.latest,
      bufferSize = null;

  /// Subscribe to the maximum value for this visualization item since last read.
  const VisualizationSubscriptionConfig.max(this.id)
    : type = VisualizationSubscriptionType.max,
      bufferSize = null;

  /// Subscribe to the last N values for this visualization item.
  const VisualizationSubscriptionConfig.lastNValues(this.id, this.bufferSize)
    : type = VisualizationSubscriptionType.lastNValues;
}

/// Represents a subscription to a visualization item.
///
/// This class is used to represent a specific data value from the engine. The
/// typical case for this is for a widget (typically a VisualizationBuilder) to
/// read this every frame (or at least regularly) and update the UI with the
/// latest value or values.
class VisualizationSubscription {
  final VisualizationProvider _parent;
  final VisualizationSubscriptionConfig _config;

  final RingBufferDouble? _buffer;
  double _value = 0;
  bool _shouldReset = false;

  /// Read the latest value for this visualization item.
  ///
  /// For the "max" subscription type, this will return the maximum value since
  /// the last read. If a subsequent read is performed before the next update,
  /// this will return the same value as the previous read.
  ///
  /// For all other subscription types, this will return the latest value.
  double readValue() {
    _shouldReset = true;
    return _value;
  }

  /// Read the last N values for this visualization item.
  ///
  /// If the configuration does not specify a subscription type with multiple
  /// values, this will return an empty list.
  Iterable<double> readValues() {
    _shouldReset = true;
    return _buffer?.values ?? [_value];
  }

  VisualizationSubscription(this._config, this._parent)
    : _buffer =
          _config.type == VisualizationSubscriptionType.lastNValues
              ? RingBufferDouble(_config.bufferSize!)
              : null;

  /// Add a new value to the subscription.
  void _addValue(double value) {
    if (_shouldReset) {
      _shouldReset = false;

      if (_config.type == VisualizationSubscriptionType.lastNValues) {
        _buffer!;

        _buffer.reset();
        _buffer.add(value);
      } else {
        _value = value;
      }
    } else {
      if (_config.type == VisualizationSubscriptionType.lastNValues) {
        _buffer!.add(value);
      } else if (_config.type == VisualizationSubscriptionType.max) {
        _value = max(_value, value);
      } else {
        _value = value;
      }
    }
  }

  void dispose() {
    _parent._unsubscribe(this);
  }
}
