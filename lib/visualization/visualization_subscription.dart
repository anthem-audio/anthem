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

enum VisualizationSubscriptionType { latest, max }

enum VisualizationBufferMode { none, adaptive }

enum _VisualizationValueType { doubleValue, intValue, stringValue }

// Adaptive subscriptions render from a delayed engine-time cursor rather than
// directly from the newest packet. This lets the UI smooth over irregular
// delivery timing while staying in the same time domain as the engine.
enum _VisualizationBufferState { passThrough, buffering, steady, stalled }

/// Represents the configuration for a visualization subscription.
class VisualizationSubscriptionConfig {
  final String id;
  final VisualizationSubscriptionType type;
  final VisualizationBufferMode bufferMode;

  /// Subscribe to the most recent value for this visualization item.
  const VisualizationSubscriptionConfig.latest(
    this.id, {
    this.bufferMode = VisualizationBufferMode.none,
  }) : type = VisualizationSubscriptionType.latest;

  /// Subscribe to the maximum value for this visualization item since the last
  /// read or rendered frame.
  const VisualizationSubscriptionConfig.max(
    this.id, {
    this.bufferMode = VisualizationBufferMode.none,
  }) : type = VisualizationSubscriptionType.max;

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VisualizationSubscriptionConfig) return false;
    return id == other.id &&
        type == other.type &&
        bufferMode == other.bufferMode;
  }

  @override
  int get hashCode => Object.hash(id, type, bufferMode);
}

/// Represents a subscription to a visualization item.
///
/// This class is used to represent a specific data value from the engine. The
/// typical case for this is for a widget (typically a VisualizationBuilder) to
/// read this every frame (or at least regularly) and update the UI with the
/// latest value.
class VisualizationSubscription {
  static const _maxBufferedDuration = Duration(seconds: 3);
  static const _maxBufferedSamples = 2048;

  final VisualizationProvider _parent;
  final VisualizationSubscriptionConfig _config;
  late final Ticker _ticker;
  final _VisualizationSampleBuffer? _sampleBuffer;

  double _sourceValueDouble = 0;
  int _sourceValueInt = 0;
  String? _sourceValueString;
  Duration? _sourceEngineTime;

  double _valueDouble = 0;
  int _valueInt = 0;
  String? _valueString;
  Duration? _engineTime;
  _VisualizationValueType? _valueType;

  Duration? _overrideSetTime;
  Duration? _overrideDuration;
  double? _overrideDouble;
  int? _overrideInt;
  String? _overrideString;

  bool _shouldReset = false;

  // `_sampleBuffer` holds raw engine-backed samples. Buffered subscriptions
  // expose a delayed view of that buffer by moving `_renderEngineTime`
  // forward every frame according to the shared transport stats.
  _VisualizationBufferState _bufferState;
  Duration? _renderEngineTime;
  Duration? _lastTickElapsed;
  Duration? _lastArrivalWallTime;
  Duration? _lastConsumedRenderTimeForMax;
  Duration? _lastConsumedEngineTime;
  Duration? _lastConsumedWallTime;

  bool _isUpdateStale = false;
  final StreamController<void> _updateController = StreamController.broadcast(
    sync: true,
  );

  /// The stream that will be triggered when the value for this subscription
  /// changes.
  ///
  /// This happens at most once per frame.
  Stream<void> get onUpdate => _updateController.stream;

  bool get _hasAdaptiveBuffering =>
      _config.bufferMode == VisualizationBufferMode.adaptive;

  bool get _hasActiveOverride =>
      _overrideDouble != null ||
      _overrideInt != null ||
      _overrideString != null;

  // Sample timestamps arrive from the engine in sample-space. Convert them to
  // durations once so all buffering and rendering logic can stay in engine
  // time.
  Duration _sampleTimestampToEngineTime(int sampleTimestamp) {
    final sampleRate = _parent._project.engine.audioConfig?.sampleRate;
    if (sampleRate == null || sampleRate <= 0) {
      throw StateError(
        'Cannot convert visualization sample timestamp to engine time for ${_config.id} because the engine audio config is unavailable.',
      );
    }

    final microseconds =
        (sampleTimestamp * Duration.microsecondsPerSecond / sampleRate).round();
    return Duration(microseconds: microseconds);
  }

  void _assertStringValueType() {
    if (_valueType == .doubleValue || _valueType == .intValue) {
      throw StateError(
        'Visualization item ${_config.id} does not contain string values.',
      );
    }
  }

  void _markConsumedEngineTime(Duration engineTime) {
    _lastConsumedEngineTime = engineTime;
    _lastConsumedWallTime = _parent._wallClockNow();
  }

  void _clearConsumedEngineTimeAnchor() {
    _lastConsumedEngineTime = null;
    _lastConsumedWallTime = null;
  }

  Duration _overrideEngineTime() {
    final anchorEngineTime = _lastConsumedEngineTime ?? Duration.zero;
    final anchorWallTime = _lastConsumedWallTime;

    if (anchorWallTime == null) {
      return anchorEngineTime;
    }

    if (_parent._project.engineState != EngineState.running) {
      return anchorEngineTime;
    }

    if (_bufferState == _VisualizationBufferState.stalled) {
      return anchorEngineTime;
    }

    final elapsed = _parent._wallClockNow() - anchorWallTime;
    return anchorEngineTime + _clampToZero(elapsed);
  }

  TimedVisualizationValue<T>? _timedValueOrNull<T>({
    T? overrideValue,
    required T Function() readRenderedValue,
    required T Function() readSourceValue,
  }) {
    if (_hasActiveOverride) {
      if (overrideValue == null) {
        return null;
      }

      final engineTime = _overrideEngineTime();
      _markConsumedEngineTime(engineTime);
      return TimedVisualizationValue<T>(
        value: overrideValue,
        engineTime: engineTime,
      );
    }

    if (_engineTime != null) {
      _markConsumedEngineTime(_engineTime!);
      return TimedVisualizationValue<T>(
        value: readRenderedValue(),
        engineTime: _engineTime!,
      );
    }

    if (_sourceEngineTime != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
      return TimedVisualizationValue<T>(
        value: readSourceValue(),
        engineTime: _sourceEngineTime!,
      );
    }

    return null;
  }

  /// Read the latest engine-backed value for this visualization item, with its
  /// engine time.
  ///
  /// Returns `null` if no engine-backed value has been received yet and there
  /// is no active UI override.
  TimedVisualizationValue<double>? readTimedValue() {
    _shouldReset = true;
    return _timedValueOrNull<double>(
      overrideValue: _overrideDouble ?? _overrideInt?.toDouble(),
      readRenderedValue: () => _valueDouble,
      readSourceValue: () => _sourceValueDouble,
    );
  }

  /// Read the latest engine-backed value as an integer for this visualization
  /// item, with its engine time.
  ///
  /// Returns `null` if no engine-backed value has been received yet and there
  /// is no active UI override.
  TimedVisualizationValue<int>? readTimedValueInt() {
    _shouldReset = true;
    return _timedValueOrNull<int>(
      overrideValue: _overrideInt,
      readRenderedValue: () => _valueInt,
      readSourceValue: () => _sourceValueInt,
    );
  }

  /// Read the latest engine-backed string value for this visualization item,
  /// with its engine time.
  ///
  /// Returns `null` if no engine-backed value has been received yet and there
  /// is no active UI override.
  TimedVisualizationValue<String>? readTimedValueString() {
    _shouldReset = true;
    _assertStringValueType();

    return _timedValueOrNull<String>(
      overrideValue: _overrideString,
      readRenderedValue: () => _valueString ?? '',
      readSourceValue: () => _sourceValueString ?? '',
    );
  }

  /// Read the latest value for this visualization item.
  ///
  /// For the "max" subscription type without buffering, this will return the
  /// maximum value since the last read. If a subsequent read is performed
  /// before the next update, this will return the same value as the previous
  /// read.
  ///
  /// For buffered subscriptions, this returns the current rendered value.
  double readValue() {
    _shouldReset = true;

    if (_overrideDouble != null) {
      return _overrideDouble!;
    }

    if (_overrideInt != null) {
      return _overrideInt!.toDouble();
    }

    if (_engineTime != null) {
      _markConsumedEngineTime(_engineTime!);
      return _valueDouble;
    }

    if (_sourceEngineTime != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
    }

    return _sourceValueDouble;
  }

  /// Read the latest value as an integer for this visualization item.
  int readValueInt() {
    _shouldReset = true;

    if (_overrideInt != null) {
      return _overrideInt!;
    }

    if (_engineTime != null) {
      _markConsumedEngineTime(_engineTime!);
      return _valueInt;
    }

    if (_sourceEngineTime != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
    }

    return _sourceValueInt;
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

    if (_engineTime != null) {
      _markConsumedEngineTime(_engineTime!);
      return _valueString ?? '';
    }

    if (_sourceEngineTime != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
    }

    return _sourceValueString ?? '';
  }

  /// Sets an override value for this subscription, with a duration.
  ///
  /// The override value will be used in place of any incoming values from
  /// the engine until the duration has elapsed. This is for values that are
  /// expected to change to a specific known value, and where an immediate
  /// update is desired (e.g. when it would prevent a flicker in the UI).
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

    _overrideSetTime = _parent._wallClockNow();
    _overrideDuration = duration;
    _overrideDouble = valueDouble;
    _overrideInt = valueInt;
    _overrideString = valueString;

    _isUpdateStale = true;
  }

  VisualizationSubscription(this._config, this._parent)
    : _sampleBuffer = _config.bufferMode == VisualizationBufferMode.adaptive
          ? _VisualizationSampleBuffer(
              maxBufferedDuration: _maxBufferedDuration,
              maxSampleCount: _maxBufferedSamples,
            )
          : null,
      _bufferState = _config.bufferMode == VisualizationBufferMode.adaptive
          ? _VisualizationBufferState.buffering
          : _VisualizationBufferState.passThrough {
    _ticker = Ticker(_onTick);
    if (_parent._project.engineState == EngineState.running) {
      _ticker.start();
    }
  }

  Duration _recommendedDelay() => _parent._transportStats.recommendedDelay;

  Duration _bufferMargin() => _parent._transportStats.bufferMargin;

  Duration _stallTimeout() => _parent._transportStats.stallTimeout;

  Duration _clampToZero(Duration duration) {
    return duration.isNegative ? Duration.zero : duration;
  }

  Duration _minDuration(Duration a, Duration b) => a <= b ? a : b;

  void _setSourceValue(Object value, Duration engineTime) {
    if (value is double) {
      _valueType = .doubleValue;
      _sourceValueDouble = value;
    } else if (value is int) {
      _valueType = .intValue;
      _sourceValueInt = value;
    } else if (value is String) {
      _valueType = .stringValue;
      _sourceValueString = value;
    } else {
      throw ArgumentError(
        'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String, int, or double.',
      );
    }

    _sourceEngineTime = engineTime;
  }

  bool _setRenderedValue(Object value, Duration engineTime) {
    var didChange = engineTime != _engineTime;
    _engineTime = engineTime;

    if (value is double) {
      _valueType = .doubleValue;
      if (_valueDouble != value) {
        _valueDouble = value;
        didChange = true;
      }
    } else if (value is int) {
      _valueType = .intValue;
      if (_valueInt != value) {
        _valueInt = value;
        didChange = true;
      }
    } else if (value is String) {
      _valueType = .stringValue;
      if (_valueString != value) {
        _valueString = value;
        didChange = true;
      }
    } else {
      throw ArgumentError(
        'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String, int, or double.',
      );
    }

    return didChange;
  }

  void _resetAdaptiveState() {
    _sampleBuffer?.clear();
    _setBufferState(_VisualizationBufferState.buffering);
    _renderEngineTime = null;
    _lastArrivalWallTime = null;
    _lastConsumedRenderTimeForMax = null;
    _engineTime = null;
    _lastTickElapsed = null;
  }

  void _resumeAdaptiveStateAfterOverride() {
    if (!_hasAdaptiveBuffering ||
        _sampleBuffer == null ||
        _sampleBuffer.isEmpty) {
      return;
    }

    _renderEngineTime = _sampleBuffer.newestEngineTime;
    _lastConsumedRenderTimeForMax = _renderEngineTime;
    _setBufferState(_VisualizationBufferState.buffering);

    final renderTime = _renderEngineTime;
    if (renderTime == null) {
      return;
    }

    if (_config.type == VisualizationSubscriptionType.latest) {
      _renderLatestValue(renderTime);
    } else {
      final latestSample = _sampleBuffer.latestAtOrBefore(renderTime);
      if (latestSample != null) {
        _setRenderedValue(latestSample.value, renderTime);
      }
    }
  }

  // Advances the buffered render cursor using wall-clock frame time while
  // trying to keep the rendered output roughly `targetDelay` behind the newest
  // buffered engine time.
  //
  // State behavior:
  // - `buffering`: wait for enough headroom before advancing
  // - `steady`: render from the delayed timeline
  // - `stalled`: stop advancing when the buffer has run dry for too long
  bool _advanceBufferedOutput(Duration elapsed) {
    if (!_hasAdaptiveBuffering ||
        _sampleBuffer == null ||
        _sampleBuffer.isEmpty) {
      _lastTickElapsed = elapsed;
      return false;
    }

    final previousElapsed = _lastTickElapsed;
    _lastTickElapsed = elapsed;

    final frameDelta = previousElapsed == null
        ? Duration.zero
        : elapsed - previousElapsed;
    final newestEngineTime = _sampleBuffer.newestEngineTime!;
    final targetDelay = _recommendedDelay();
    final bufferMargin = _bufferMargin();
    final lowWater = _clampToZero(targetDelay - bufferMargin);
    final highWater = targetDelay + bufferMargin;
    final currentAhead = _renderEngineTime == null
        ? Duration.zero
        : newestEngineTime - _renderEngineTime!;

    if (_renderEngineTime == null) {
      // Do not begin rendering until enough data exists to satisfy the current
      // target delay without immediately underrunning.
      if (_sampleBuffer.span < highWater) {
        _setBufferState(_VisualizationBufferState.buffering);
        return false;
      }

      _renderEngineTime = _sampleBuffer.clampEngineTime(
        newestEngineTime - targetDelay,
      );
      _lastConsumedRenderTimeForMax = null;
      _setBufferState(_VisualizationBufferState.steady);
      return _renderCurrentBufferedValue();
    }

    if (_bufferState == _VisualizationBufferState.steady &&
        currentAhead < lowWater) {
      // If the render cursor gets too close to the newest buffered data, pause
      // advancement until the buffer refills.
      _setBufferState(_VisualizationBufferState.buffering);
    }

    final timeSinceArrival = _lastArrivalWallTime == null
        ? Duration.zero
        : _parent._wallClockNow() - _lastArrivalWallTime!;
    final hasTimedOut = timeSinceArrival >= _stallTimeout();

    if (_bufferState == _VisualizationBufferState.buffering) {
      if (currentAhead >= highWater) {
        _setBufferState(_VisualizationBufferState.steady);
      } else if (hasTimedOut && currentAhead <= Duration.zero) {
        _setBufferState(_VisualizationBufferState.stalled);
      } else {
        return false;
      }
    }

    if (_bufferState == _VisualizationBufferState.stalled) {
      if (currentAhead >= highWater) {
        _setBufferState(_VisualizationBufferState.steady);
      } else {
        return false;
      }
    }

    final desiredRenderTime = _sampleBuffer.clampEngineTime(
      newestEngineTime - targetDelay,
    );
    var advance = frameDelta;

    if (currentAhead > highWater && frameDelta > Duration.zero) {
      // When the buffer grows beyond the target delay, catch up gradually
      // instead of snapping the cursor forward.
      final extraCatchUp = _minDuration(currentAhead - targetDelay, frameDelta);
      advance += extraCatchUp;
    }

    var nextRenderTime = _renderEngineTime! + advance;
    if (nextRenderTime > desiredRenderTime) {
      nextRenderTime = desiredRenderTime;
    }
    if (nextRenderTime < _renderEngineTime!) {
      nextRenderTime = _renderEngineTime!;
    }

    if (nextRenderTime == _renderEngineTime) {
      if (hasTimedOut && currentAhead <= Duration.zero) {
        _setBufferState(_VisualizationBufferState.stalled);
      }
      return false;
    }

    _renderEngineTime = nextRenderTime;
    return _renderCurrentBufferedValue();
  }

  bool _renderCurrentBufferedValue() {
    final renderTime = _renderEngineTime;
    if (renderTime == null || _sampleBuffer == null) {
      return false;
    }

    return switch (_config.type) {
      VisualizationSubscriptionType.latest => _renderLatestValue(renderTime),
      VisualizationSubscriptionType.max => _renderMaxValue(renderTime),
    };
  }

  // `latest` subscriptions use sample-and-hold against the delayed cursor.
  // Arrival jitter is handled by buffering; values themselves are not
  // interpolated between engine samples.
  bool _renderLatestValue(Duration renderTime) {
    final latestBefore = _sampleBuffer?.latestAtOrBefore(renderTime);
    final earliestAfter = _sampleBuffer?.earliestAfter(renderTime);
    final anchor = latestBefore ?? earliestAfter;
    if (anchor == null) {
      return false;
    }

    return _setRenderedValue(anchor.value, renderTime);
  }

  // `max` subscriptions preserve peak-style behavior by aggregating over the
  // raw samples that became visible since the previous rendered frame.
  bool _renderMaxValue(Duration renderTime) {
    final previousConsumedTime = _lastConsumedRenderTimeForMax;
    _lastConsumedRenderTimeForMax = renderTime;

    final samples = _sampleBuffer?.between(
      afterExclusive: previousConsumedTime,
      upToInclusive: renderTime,
    );

    if (samples == null || samples.isEmpty) {
      if (_engineTime == null) {
        final latestSample = _sampleBuffer?.latestAtOrBefore(renderTime);
        if (latestSample != null) {
          return _setRenderedValue(latestSample.value, renderTime);
        }
      }

      if (_engineTime != null &&
          _valueType == _VisualizationValueType.doubleValue) {
        return _setRenderedValue(_valueDouble, renderTime);
      }

      return false;
    }

    if (_valueType != null &&
        _valueType != _VisualizationValueType.doubleValue &&
        _valueType != _VisualizationValueType.intValue &&
        _valueType != _VisualizationValueType.stringValue) {
      throw StateError(
        'Unexpected visualization value type for ${_config.id}.',
      );
    }

    final firstValue = samples.first.value;
    if (firstValue is! double) {
      throw StateError(
        'Visualization item ${_config.id} uses max buffering but does not contain double values.',
      );
    }

    var maxValue = firstValue;
    for (final sample in samples.skip(1)) {
      final value = sample.value;
      if (value is! double) {
        throw StateError(
          'Visualization item ${_config.id} uses max buffering but does not contain double values.',
        );
      }
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return _setRenderedValue(maxValue, renderTime);
  }

  bool _expireOverrideIfNeeded() {
    if (_overrideSetTime == null || _overrideDuration == null) {
      return false;
    }

    final elapsed = _parent._wallClockNow() - _overrideSetTime!;
    if (elapsed < _overrideDuration!) {
      return false;
    }

    _overrideSetTime = null;
    _overrideDuration = null;
    _overrideDouble = null;
    _overrideInt = null;
    _overrideString = null;

    if (_hasAdaptiveBuffering) {
      _resumeAdaptiveStateAfterOverride();
    }

    return true;
  }

  /// Called when the [_ticker] ticks.
  void _onTick(Duration elapsed) {
    var shouldEmit = false;

    if (_expireOverrideIfNeeded()) {
      shouldEmit = true;
    }

    if (_hasAdaptiveBuffering && !_hasActiveOverride) {
      shouldEmit = _advanceBufferedOutput(elapsed) || shouldEmit;
    }

    if (_isUpdateStale || shouldEmit) {
      _isUpdateStale = false;
      _updateController.add(null);
    }
  }

  void _addUnbufferedValue(Object value, Duration engineTime) {
    if ((_sourceEngineTime != null && engineTime < _sourceEngineTime!) ||
        (_engineTime != null && engineTime < _engineTime!)) {
      _clearConsumedEngineTimeAnchor();
    }

    _setSourceValue(value, engineTime);

    if (_shouldReset) {
      _shouldReset = false;
      _setRenderedValue(value, engineTime);
      _isUpdateStale = true;
      return;
    }

    if (value is double) {
      _valueType = .doubleValue;
      if (_config.type == VisualizationSubscriptionType.max) {
        if (_engineTime == null || value > _valueDouble) {
          _valueDouble = value;
          _engineTime = engineTime;
        }
      } else {
        _valueDouble = value;
        _engineTime = engineTime;
      }
    } else if (value is int) {
      _valueType = .intValue;
      if (_config.type == VisualizationSubscriptionType.max) {
        throw StateError(
          'Int values are not supported for max subscription type.',
        );
      }

      _valueInt = value;
      _engineTime = engineTime;
    } else if (value is String) {
      _valueType = .stringValue;
      if (_config.type == VisualizationSubscriptionType.max) {
        throw StateError(
          'String values are not supported for max subscription type.',
        );
      }

      _valueString = value;
      _engineTime = engineTime;
    } else {
      throw ArgumentError(
        'Unexpected value type: ${value.runtimeType} for item ${_config.id}. Expected String, int, or double.',
      );
    }

    _isUpdateStale = true;
  }

  void _addBufferedValue(Object value, Duration engineTime) {
    _setSourceValue(value, engineTime);

    final newestEngineTime = _sampleBuffer?.newestEngineTime;
    if (newestEngineTime != null && engineTime < newestEngineTime) {
      _clearConsumedEngineTimeAnchor();
      _resetAdaptiveState();
    }

    _sampleBuffer?.add(value, engineTime);
    _lastArrivalWallTime = _parent._wallClockNow();

    if (_bufferState == _VisualizationBufferState.stalled) {
      _setBufferState(_VisualizationBufferState.buffering);
    }

    _isUpdateStale = true;
  }

  void _setBufferState(_VisualizationBufferState state) {
    _bufferState = state;
  }

  /// Add a new value to the subscription.
  void _addValue(
    Object /* String | int | double */ value,
    int sampleTimestamp,
  ) {
    final engineTime = _sampleTimestampToEngineTime(sampleTimestamp);

    if (_hasAdaptiveBuffering) {
      _addBufferedValue(value, engineTime);
    } else {
      _addUnbufferedValue(value, engineTime);
    }
  }

  void _engineStarted() {
    _lastTickElapsed = null;

    if (_ticker.isActive) {
      return;
    }

    _ticker.start();
  }

  void _engineStopped() {
    _lastTickElapsed = null;

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

class _BufferedVisualizationSample {
  final Object value;
  final Duration engineTime;

  const _BufferedVisualizationSample({
    required this.value,
    required this.engineTime,
  });
}

class _VisualizationSampleBuffer {
  final Duration maxBufferedDuration;
  final int maxSampleCount;
  final List<_BufferedVisualizationSample> _samples = [];

  _VisualizationSampleBuffer({
    required this.maxBufferedDuration,
    required this.maxSampleCount,
  });

  bool get isEmpty => _samples.isEmpty;

  int get sampleCount => _samples.length;

  Duration? get newestEngineTime => isEmpty ? null : _samples.last.engineTime;

  Duration? get oldestEngineTime => isEmpty ? null : _samples.first.engineTime;

  Duration get span {
    final oldest = oldestEngineTime;
    final newest = newestEngineTime;
    if (oldest == null || newest == null) {
      return Duration.zero;
    }

    return newest - oldest;
  }

  void add(Object value, Duration engineTime) {
    _samples.add(
      _BufferedVisualizationSample(value: value, engineTime: engineTime),
    );
    _trim();
  }

  void clear() {
    _samples.clear();
  }

  Duration clampEngineTime(Duration engineTime) {
    final oldest = oldestEngineTime;
    final newest = newestEngineTime;
    if (oldest == null || newest == null) {
      return engineTime;
    }

    if (engineTime < oldest) {
      return oldest;
    }
    if (engineTime > newest) {
      return newest;
    }

    return engineTime;
  }

  _BufferedVisualizationSample? latestAtOrBefore(Duration engineTime) {
    for (var i = _samples.length - 1; i >= 0; i--) {
      final sample = _samples[i];
      if (sample.engineTime <= engineTime) {
        return sample;
      }
    }

    return null;
  }

  _BufferedVisualizationSample? earliestAfter(Duration engineTime) {
    for (final sample in _samples) {
      if (sample.engineTime > engineTime) {
        return sample;
      }
    }

    return null;
  }

  List<_BufferedVisualizationSample> between({
    Duration? afterExclusive,
    required Duration upToInclusive,
  }) {
    return _samples
        .where((sample) {
          final afterLowerBound = afterExclusive == null
              ? true
              : sample.engineTime > afterExclusive;
          return afterLowerBound && sample.engineTime <= upToInclusive;
        })
        .toList(growable: false);
  }

  void _trim() {
    while (_samples.length > maxSampleCount) {
      _samples.removeAt(0);
    }

    final newest = newestEngineTime;
    if (newest == null) {
      return;
    }

    while (_samples.length > 1 &&
        newest - _samples.first.engineTime > maxBufferedDuration) {
      _samples.removeAt(0);
    }
  }
}
