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

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VisualizationSubscriptionConfig) return false;
    return id == other.id &&
        type == other.type &&
        bufferSize == other.bufferSize;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode ^ bufferSize.hashCode;
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
  late final Ticker _ticker;

  final RingBuffer<double>? _ringBufferDouble;
  final RingBuffer<String>? _ringBufferString;

  double _valueDouble = 0;
  String? _valueString;

  DateTime? _overrideSetTime;
  Duration? _overrideDuration;
  double? _overrideDouble;
  String? _overrideString;

  bool _shouldReset = false;

  bool _isUpdateStale = false;
  final StreamController<void> _updateController = StreamController.broadcast(
    sync: true,
  );

  /// The stream that will be triggered when the value for this subscription
  /// changes.
  ///
  /// This happens at most once per frame.
  Stream<void> get onUpdate => _updateController.stream;

  /// Read the latest value for this visualization item.
  ///
  /// For the "max" subscription type, this will return the maximum value since
  /// the last read. If a subsequent read is performed before the next update,
  /// this will return the same value as the previous read.
  ///
  /// For all other subscription types, this will return the latest value.
  double readValue() {
    _shouldReset = true;
    return _overrideDouble ?? _valueDouble;
  }

  /// Read the latest value as a string for this visualization item.
  ///
  /// For most visualization items, this will read out the current value as a
  /// string. However, some items only have a string representation. For
  /// example, the current transport position comes paired with another value
  /// that says which sequence is currently playing. This item does not have
  /// a numeric value, and is instead the ID of the sequence as a string.
  String readValueString() {
    _shouldReset = true;
    return _overrideString ??
        _overrideDouble?.toString() ??
        _valueString ??
        _valueDouble.toString();
  }

  /// Read the last N values for this visualization item.
  ///
  /// If the configuration does not specify a subscription type with multiple
  /// values, this will return the result of [readValue] as a single-item list.
  Iterable<double> readValues() {
    _shouldReset = true;

    if (_overrideDouble != null) {
      return [_overrideDouble!];
    }

    return _ringBufferDouble?.values ?? [_valueDouble];
  }

  /// Reads the last N values as strings for this visualization item.
  ///
  /// If the configuration does not specify a subscription type with multiple
  /// values, this will return the result of [readValueString] as a single-item
  /// list.
  Iterable<String> readValuesString() {
    _shouldReset = true;

    if (_overrideString != null) {
      return [_overrideString!];
    }

    return _ringBufferString?.values ??
        [_valueString ?? _valueDouble.toString()];
  }

  /// Sets an override value for this subscription, with a duration.
  ///
  /// The override value will be used in place of any incoming values from
  /// the engine until the duration has elapsed. This is for values that are
  /// expected to change to a specific known value, and where an immediate update
  /// is desired (e.g. when it would prevent a flicker in the UI).
  void setOverride({
    double? valueDouble,
    String? valueString,
    required Duration duration,
  }) {
    if (valueDouble == null && valueString == null) {
      throw ArgumentError(
        'Either valueDouble or valueString must be provided.',
      );
    }

    _overrideSetTime = DateTime.now();
    _overrideDuration = duration;
    _overrideDouble = valueDouble;
    _overrideString = valueString;

    _isUpdateStale = true;
  }

  VisualizationSubscription(this._config, this._parent)
    : _ringBufferDouble =
          _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<double>(_config.bufferSize!)
          : null,
      _ringBufferString =
          _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<String>(_config.bufferSize!)
          : null {
    _ticker = Ticker(_onTick);
    if (_parent._project.engineState == EngineState.running) {
      _ticker.start();
    }
  }

  /// Called when the [_ticker] ticks.
  void _onTick(Duration elapsed) {
    if (_isUpdateStale) {
      _isUpdateStale = false;
      _updateController.add(null);
    }

    if (_overrideSetTime != null && _overrideDuration != null) {
      final elapsed = DateTime.now().difference(_overrideSetTime!);
      if (elapsed >= _overrideDuration!) {
        _overrideSetTime = null;
        _overrideDuration = null;
        _overrideDouble = null;
        _overrideString = null;
        _isUpdateStale = true;
      }
    }
  }

  /// Add a new value to the subscription.
  void _addValue(Object /* String | double */ value) {
    if (_shouldReset) {
      _shouldReset = false;

      if (value is double) {
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferDouble!;

          _ringBufferDouble.reset();
          _ringBufferDouble.add(value);
        } else {
          _valueDouble = value;
        }
      } else if (value is String) {
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferString!;

          _ringBufferString.reset();
          _ringBufferString.add(value);
        } else {
          _valueString = value;
        }
      } else {
        throw ArgumentError(
          'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String or double.',
        );
      }
    } else {
      if (value is double) {
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferDouble!.add(value);
        } else if (_config.type == VisualizationSubscriptionType.max) {
          _valueDouble = max(_valueDouble, value);
        } else {
          _valueDouble = value;
        }
      } else if (value is String) {
        assert(
          _config.type != VisualizationSubscriptionType.max,
          'String values are not supported for max subscription type.',
        );

        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferString!.add(value);
        } else {
          _valueString = value;
        }
      } else {
        throw ArgumentError(
          'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String or double.',
        );
      }
    }

    _isUpdateStale = true;
  }

  void _engineStarted() {
    if (_ticker.isActive) {
      return;
    }

    _ticker.start();
  }

  void _engineStopped() {
    if (!_ticker.isActive) {
      return;
    }

    _ticker.stop();
  }

  void dispose() {
    _parent._unsubscribe(this);
    _ticker.dispose();
    _updateController.close();
  }
}
