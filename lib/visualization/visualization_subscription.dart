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

part of 'visualization.dart';

enum VisualizationSubscriptionType { latest, max, lastNValues }

enum _VisualizationValueType { doubleValue, intValue, stringValue }

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
  final RingBuffer<int>? _ringBufferInt;
  final RingBuffer<String>? _ringBufferString;
  final RingBuffer<int>? _ringBufferSampleTimestamp;

  double _valueDouble = 0;
  int _valueInt = 0;
  String? _valueString;
  int? _sampleTimestamp;
  _VisualizationValueType? _valueType;

  DateTime? _overrideSetTime;
  Duration? _overrideDuration;
  double? _overrideDouble;
  int? _overrideInt;
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

  bool get _hasActiveOverride =>
      _overrideDouble != null ||
      _overrideInt != null ||
      _overrideString != null;

  List<TimedVisualizationValue<T>> _pairValuesWithTimestamps<T>(
    Iterable<T> values,
  ) {
    final valueList = values.toList(growable: false);
    final timestampList =
        _ringBufferSampleTimestamp?.values.toList(growable: false) ??
        (_sampleTimestamp == null ? <int>[] : <int>[_sampleTimestamp!]);

    if (timestampList.isEmpty) {
      return <TimedVisualizationValue<T>>[];
    }

    if (timestampList.length != valueList.length) {
      throw StateError(
        'Visualization value/timestamp length mismatch for ${_config.id}: '
        '${valueList.length} values vs ${timestampList.length} timestamps.',
      );
    }

    return List.generate(valueList.length, (index) {
      return TimedVisualizationValue<T>(
        value: valueList[index],
        sampleTimestamp: timestampList[index],
      );
    }, growable: false);
  }

  TimedVisualizationValue<T>? _lastTimedValueOrNull<T>(
    Iterable<TimedVisualizationValue<T>> values,
  ) {
    TimedVisualizationValue<T>? result;

    for (final value in values) {
      result = value;
    }

    return result;
  }

  /// Read the latest engine-backed value for this visualization item, with its
  /// sample timestamp.
  ///
  /// Returns `null` if no engine-backed value has been received yet, or if a
  /// UI override is currently active.
  TimedVisualizationValue<double>? readTimedValue() {
    return _lastTimedValueOrNull(readTimedValues());
  }

  /// Read the latest engine-backed value as an integer for this visualization
  /// item, with its sample timestamp.
  ///
  /// Returns `null` if no engine-backed value has been received yet, or if a
  /// UI override is currently active.
  TimedVisualizationValue<int>? readTimedValueInt() {
    return _lastTimedValueOrNull(readTimedValuesInt());
  }

  void _assertStringValueType() {
    if (_valueType == .doubleValue || _valueType == .intValue) {
      throw StateError(
        'Visualization item ${_config.id} does not contain string values.',
      );
    }
  }

  /// Read the latest engine-backed string value for this visualization item,
  /// with its sample timestamp.
  ///
  /// Returns `null` if no engine-backed value has been received yet, or if a
  /// UI override is currently active.
  TimedVisualizationValue<String>? readTimedValueString() {
    return _lastTimedValueOrNull(readTimedValuesString());
  }

  /// Read the last N engine-backed values for this visualization item, with
  /// their sample timestamps.
  ///
  /// If the configuration does not specify a subscription type with multiple
  /// values, this will return either an empty iterable or a single-item
  /// iterable.
  Iterable<TimedVisualizationValue<double>> readTimedValues() {
    _shouldReset = true;

    if (_hasActiveOverride) {
      return const [];
    }

    return _pairValuesWithTimestamps<double>(
      _ringBufferDouble?.values ?? [_valueDouble],
    );
  }

  /// Read the last N engine-backed values as integers for this visualization
  /// item, with their sample timestamps.
  Iterable<TimedVisualizationValue<int>> readTimedValuesInt() {
    _shouldReset = true;

    if (_hasActiveOverride) {
      return const [];
    }

    return _pairValuesWithTimestamps<int>(
      _ringBufferInt?.values ?? [_valueInt],
    );
  }

  /// Read the last N engine-backed string values for this visualization item,
  /// with their sample timestamps.
  Iterable<TimedVisualizationValue<String>> readTimedValuesString() {
    _shouldReset = true;

    if (_hasActiveOverride) {
      return const [];
    }

    _assertStringValueType();

    return _pairValuesWithTimestamps<String>(
      _ringBufferString?.values ??
          (_valueString == null ? const <String>[] : [_valueString!]),
    );
  }

  /// Read the latest value for this visualization item.
  ///
  /// For the "max" subscription type, this will return the maximum value since
  /// the last read. If a subsequent read is performed before the next update,
  /// this will return the same value as the previous read.
  ///
  /// For all other subscription types, this will return the latest value.
  double readValue() {
    _shouldReset = true;
    return _overrideDouble ?? _overrideInt?.toDouble() ?? _valueDouble;
  }

  /// Read the latest value as an integer for this visualization item.
  int readValueInt() {
    _shouldReset = true;
    return _overrideInt ?? _valueInt;
  }

  /// Read the latest value as a string for this visualization item.
  ///
  /// This only reads native string values.
  String readValueString() {
    _shouldReset = true;
    if (_overrideString != null) {
      return _overrideString!;
    }

    _assertStringValueType();
    return _valueString ?? '';
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

    if (_overrideInt != null) {
      return [_overrideInt!.toDouble()];
    }

    return _ringBufferDouble?.values ?? [_valueDouble];
  }

  /// Read the last N values as integers for this visualization item.
  ///
  /// If the configuration does not specify a subscription type with multiple
  /// values, this will return the result of [readValueInt] as a single-item
  /// list.
  Iterable<int> readValuesInt() {
    _shouldReset = true;

    if (_overrideInt != null) {
      return [_overrideInt!];
    }

    return _ringBufferInt?.values ?? [_valueInt];
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

    _assertStringValueType();
    return _ringBufferString?.values ?? [_valueString ?? ''];
  }

  /// Sets an override value for this subscription, with a duration.
  ///
  /// The override value will be used in place of any incoming values from
  /// the engine until the duration has elapsed. This is for values that are
  /// expected to change to a specific known value, and where an immediate update
  /// is desired (e.g. when it would prevent a flicker in the UI).
  void setOverride({
    double? valueDouble,
    int? valueInt,
    String? valueString,
    required Duration duration,
  }) {
    if (valueDouble == null && valueInt == null && valueString == null) {
      throw ArgumentError(
        'Either valueDouble, valueInt, or valueString must be provided.',
      );
    }

    _overrideSetTime = DateTime.now();
    _overrideDuration = duration;
    _overrideDouble = valueDouble;
    _overrideInt = valueInt;
    _overrideString = valueString;

    _isUpdateStale = true;
  }

  VisualizationSubscription(this._config, this._parent)
    : _ringBufferDouble =
          _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<double>(_config.bufferSize!)
          : null,
      _ringBufferInt = _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<int>(_config.bufferSize!)
          : null,
      _ringBufferString =
          _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<String>(_config.bufferSize!)
          : null,
      _ringBufferSampleTimestamp =
          _config.type == VisualizationSubscriptionType.lastNValues
          ? RingBuffer<int>(_config.bufferSize!)
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
        _overrideInt = null;
        _overrideString = null;
        _isUpdateStale = true;
      }
    }
  }

  /// Add a new value to the subscription.
  void _addValue(
    Object /* String | int | double */ value,
    int sampleTimestamp,
  ) {
    if (_shouldReset) {
      _shouldReset = false;

      if (value is double) {
        _valueType = .doubleValue;
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferDouble!.reset();
          _ringBufferSampleTimestamp!.reset();
          _ringBufferDouble.add(value);
          _ringBufferSampleTimestamp.add(sampleTimestamp);
        } else {
          _valueDouble = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else if (value is int) {
        _valueType = .intValue;
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferInt!.reset();
          _ringBufferSampleTimestamp!.reset();
          _ringBufferInt.add(value);
          _ringBufferSampleTimestamp.add(sampleTimestamp);
        } else {
          _valueInt = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else if (value is String) {
        _valueType = .stringValue;
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferString!.reset();
          _ringBufferSampleTimestamp!.reset();
          _ringBufferString.add(value);
          _ringBufferSampleTimestamp.add(sampleTimestamp);
        } else {
          _valueString = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else {
        throw ArgumentError(
          'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String, int, or double.',
        );
      }
    } else {
      if (value is double) {
        _valueType = .doubleValue;
        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferDouble!.add(value);
          _ringBufferSampleTimestamp!.add(sampleTimestamp);
        } else if (_config.type == VisualizationSubscriptionType.max) {
          if (value > _valueDouble) {
            _valueDouble = value;
            _sampleTimestamp = sampleTimestamp;
          }
        } else {
          _valueDouble = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else if (value is int) {
        _valueType = .intValue;
        assert(
          _config.type != VisualizationSubscriptionType.max,
          'Int values are not supported for max subscription type.',
        );

        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferInt!.add(value);
          _ringBufferSampleTimestamp!.add(sampleTimestamp);
        } else {
          _valueInt = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else if (value is String) {
        _valueType = .stringValue;
        assert(
          _config.type != VisualizationSubscriptionType.max,
          'String values are not supported for max subscription type.',
        );

        if (_config.type == VisualizationSubscriptionType.lastNValues) {
          _ringBufferString!.add(value);
          _ringBufferSampleTimestamp!.add(sampleTimestamp);
        } else {
          _valueString = value;
          _sampleTimestamp = sampleTimestamp;
        }
      } else {
        throw ArgumentError(
          'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String, int, or double.',
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
