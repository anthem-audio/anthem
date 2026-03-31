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

// Adaptive subscriptions render from a delayed engine-time cursor rather than
// directly from the newest packet. This lets the UI smooth over irregular
// delivery timing while staying in the same time domain as the engine.
enum _VisualizationBufferState { passThrough, buffering, steady, stalled }

/// Represents the configuration for a visualization subscription.
class VisualizationSubscriptionConfig<T> {
  final String id;
  final VisualizationSubscriptionType type;
  final VisualizationBufferMode bufferMode;
  final VisualizationType<T> visualizationType;

  const VisualizationSubscriptionConfig._({
    required this.id,
    required this.type,
    required this.bufferMode,
    required this.visualizationType,
  });

  /// Subscribe to the most recent double value for this visualization item.
  static VisualizationSubscriptionConfig<double> latestDouble(
    String id, {
    VisualizationBufferMode bufferMode = VisualizationBufferMode.none,
  }) {
    return VisualizationSubscriptionConfig<double>._(
      id: id,
      type: VisualizationSubscriptionType.latest,
      bufferMode: bufferMode,
      visualizationType: doubleVisualizationType,
    );
  }

  /// Subscribe to the most recent integer value for this visualization item.
  static VisualizationSubscriptionConfig<int> latestInt(
    String id, {
    VisualizationBufferMode bufferMode = VisualizationBufferMode.none,
  }) {
    return VisualizationSubscriptionConfig<int>._(
      id: id,
      type: VisualizationSubscriptionType.latest,
      bufferMode: bufferMode,
      visualizationType: intVisualizationType,
    );
  }

  /// Subscribe to the most recent string value for this visualization item.
  static VisualizationSubscriptionConfig<String> latestString(
    String id, {
    VisualizationBufferMode bufferMode = VisualizationBufferMode.none,
  }) {
    return VisualizationSubscriptionConfig<String>._(
      id: id,
      type: VisualizationSubscriptionType.latest,
      bufferMode: bufferMode,
      visualizationType: stringVisualizationType,
    );
  }

  /// Subscribe to the maximum value for this visualization item since the last
  /// read or rendered frame.
  static VisualizationSubscriptionConfig<double> max(
    String id, {
    VisualizationBufferMode bufferMode = VisualizationBufferMode.none,
  }) {
    return VisualizationSubscriptionConfig<double>._(
      id: id,
      type: VisualizationSubscriptionType.max,
      bufferMode: bufferMode,
      visualizationType: doubleVisualizationType,
    );
  }

  VisualizationValueType get valueType => visualizationType.wireType;

  VisualizationSubscriptionSpec toSubscriptionSpec() {
    return VisualizationSubscriptionSpec(id: id, valueType: valueType);
  }

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VisualizationSubscriptionConfig<T>) return false;
    return id == other.id &&
        type == other.type &&
        bufferMode == other.bufferMode &&
        valueType == other.valueType;
  }

  @override
  int get hashCode => Object.hash(id, type, bufferMode, valueType);
}

abstract class _VisualizationSubscriptionBase {
  String get id;
  VisualizationValueType get valueType;
  Stream<void> get onUpdate;

  VisualizationSubscriptionSpec toSubscriptionSpec();
  void _addValueFromEngine(Object value, int sampleTimestamp);
  void _setOverrideValue(Object value, Duration duration);
  void _engineStarted();
  void _engineStopped();
  void dispose();
}

/// Represents a subscription to a visualization item.
///
/// This class is used to represent a specific typed data stream from the
/// engine. Widgets typically read this every frame, or when signalled by
/// [onUpdate], to render the latest engine-backed value.
abstract class VisualizationSubscription<T>
    implements _VisualizationSubscriptionBase {
  static const _maxBufferedDuration = Duration(seconds: 3);
  static const _maxBufferedSamples = 2048;

  final VisualizationProvider _parent;
  final VisualizationSubscriptionConfig<T> _config;
  late final Ticker _ticker;
  final _VisualizationSampleBuffer<T>? _sampleBuffer;

  T? _sourceValue;
  Duration? _sourceEngineTime;

  T? _value;
  Duration? _engineTime;

  T? _overrideValue;
  Duration? _overrideSetTime;
  Duration? _overrideDuration;

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

  @override
  String get id => _config.id;

  @override
  VisualizationValueType get valueType => _config.valueType;

  @override
  Stream<void> get onUpdate => _updateController.stream;

  bool get _hasAdaptiveBuffering =>
      _config.bufferMode == VisualizationBufferMode.adaptive;

  bool get _hasActiveOverride => _overrideValue != null;

  VisualizationSubscription(this._config, this._parent)
    : _sampleBuffer = _config.bufferMode == VisualizationBufferMode.adaptive
          ? _VisualizationSampleBuffer<T>(
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

  @override
  VisualizationSubscriptionSpec toSubscriptionSpec() {
    return _config.toSubscriptionSpec();
  }

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

  void _markConsumedEngineTime(Duration engineTime) {
    _lastConsumedEngineTime = engineTime;
    _lastConsumedWallTime = _parent.clock.now();
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

    final elapsed = _parent.clock.now() - anchorWallTime;
    return anchorEngineTime + _clampToZero(elapsed);
  }

  /// Read the latest engine-backed value for this visualization item, with its
  /// engine time.
  ///
  /// Returns `null` if no engine-backed value has been received yet and there
  /// is no active UI override.
  TimedVisualizationValue<T>? readTimedValue() {
    _shouldReset = true;

    if (_hasActiveOverride) {
      final value = _overrideValue;
      if (value == null) {
        return null;
      }

      final engineTime = _overrideEngineTime();
      _markConsumedEngineTime(engineTime);
      return TimedVisualizationValue<T>(value: value, engineTime: engineTime);
    }

    if (_engineTime != null && _value != null) {
      _markConsumedEngineTime(_engineTime!);
      return TimedVisualizationValue<T>(
        value: _value as T,
        engineTime: _engineTime!,
      );
    }

    if (_sourceEngineTime != null && _sourceValue != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
      return TimedVisualizationValue<T>(
        value: _sourceValue as T,
        engineTime: _sourceEngineTime!,
      );
    }

    return null;
  }

  /// Read the latest value for this visualization item.
  ///
  /// For the "max" subscription type without buffering, this will return the
  /// maximum value since the last read. If a subsequent read is performed
  /// before the next update, this will return the same value as the previous
  /// read.
  ///
  /// For buffered subscriptions, this returns the current rendered value.
  T readValue() {
    _shouldReset = true;

    if (_overrideValue != null) {
      return _overrideValue as T;
    }

    if (_engineTime != null && _value != null) {
      _markConsumedEngineTime(_engineTime!);
      return _value as T;
    }

    if (_sourceEngineTime != null) {
      _markConsumedEngineTime(_sourceEngineTime!);
    }

    return _sourceValue ?? _config.visualizationType.defaultValue;
  }

  /// Sets an override value for this subscription, with a duration.
  ///
  /// The override value will be used in place of any incoming values from
  /// the engine until the duration has elapsed. This is for values that are
  /// expected to change to a specific known value, and where an immediate
  /// update is desired (e.g. when it would prevent a flicker in the UI).
  void setOverride({required T value, required Duration duration}) {
    _overrideSetTime = _parent.clock.now();
    _overrideDuration = duration;
    _overrideValue = value;
    _isUpdateStale = true;
  }

  @override
  void _setOverrideValue(Object value, Duration duration) {
    setOverride(
      value: _config.visualizationType.cast(value),
      duration: duration,
    );
  }

  Duration _recommendedDelay() => _parent._transportStats.recommendedDelay;

  Duration _bufferMargin() => _parent._transportStats.bufferMargin;

  Duration _stallTimeout() => _parent._transportStats.stallTimeout;

  Duration _clampToZero(Duration duration) {
    return duration.isNegative ? Duration.zero : duration;
  }

  Duration _minDuration(Duration a, Duration b) => a <= b ? a : b;

  void _setSourceValue(T value, Duration engineTime) {
    _sourceValue = value;
    _sourceEngineTime = engineTime;
  }

  bool _setRenderedValue(T value, Duration engineTime) {
    var didChange = engineTime != _engineTime;
    _engineTime = engineTime;

    if (_value != value) {
      _value = value;
      didChange = true;
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
    _value = null;
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

    _renderBufferedValue(renderTime);
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
        : _parent.clock.now() - _lastArrivalWallTime!;
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

    return _renderBufferedValue(renderTime);
  }

  bool _renderLatestValue(Duration renderTime) {
    final latestBefore = _sampleBuffer?.latestAtOrBefore(renderTime);
    final earliestAfter = _sampleBuffer?.earliestAfter(renderTime);
    final anchor = latestBefore ?? earliestAfter;
    if (anchor == null) {
      return false;
    }

    return _setRenderedValue(anchor.value, renderTime);
  }

  bool _expireOverrideIfNeeded() {
    if (_overrideSetTime == null || _overrideDuration == null) {
      return false;
    }

    final elapsed = _parent.clock.now() - _overrideSetTime!;
    if (elapsed < _overrideDuration!) {
      return false;
    }

    _overrideSetTime = null;
    _overrideDuration = null;
    _overrideValue = null;

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

  void _addUnbufferedValue(T value, Duration engineTime) {
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

    _applyIncomingUnbufferedValue(value, engineTime);
    _isUpdateStale = true;
  }

  void _addBufferedValue(T value, Duration engineTime) {
    _setSourceValue(value, engineTime);

    final newestEngineTime = _sampleBuffer?.newestEngineTime;
    if (newestEngineTime != null && engineTime < newestEngineTime) {
      _clearConsumedEngineTimeAnchor();
      _resetAdaptiveState();
    }

    _sampleBuffer?.add(value, engineTime);
    _lastArrivalWallTime = _parent.clock.now();

    if (_bufferState == _VisualizationBufferState.stalled) {
      _setBufferState(_VisualizationBufferState.buffering);
    }

    _isUpdateStale = true;
  }

  void _setBufferState(_VisualizationBufferState state) {
    _bufferState = state;
  }

  @override
  void _addValueFromEngine(Object value, int sampleTimestamp) {
    final engineTime = _sampleTimestampToEngineTime(sampleTimestamp);
    final typedValue = _config.visualizationType.cast(value);

    if (_hasAdaptiveBuffering) {
      _addBufferedValue(typedValue, engineTime);
    } else {
      _addUnbufferedValue(typedValue, engineTime);
    }
  }

  void _applyIncomingUnbufferedValue(T value, Duration engineTime);
  bool _renderBufferedValue(Duration renderTime);

  @override
  void _engineStarted() {
    _lastTickElapsed = null;

    if (_ticker.isActive) {
      return;
    }

    _ticker.start();
  }

  @override
  void _engineStopped() {
    _lastTickElapsed = null;

    if (!_ticker.isActive) {
      return;
    }

    _ticker.stop();
  }

  @override
  void dispose() {
    _parent._unsubscribe(this);
    _ticker.dispose();
    _updateController.close();
  }
}

class _LatestVisualizationSubscription<T> extends VisualizationSubscription<T> {
  _LatestVisualizationSubscription(super.config, super.parent);

  @override
  void _applyIncomingUnbufferedValue(T value, Duration engineTime) {
    _setRenderedValue(value, engineTime);
  }

  @override
  bool _renderBufferedValue(Duration renderTime) {
    return _renderLatestValue(renderTime);
  }
}

class _MaxVisualizationSubscription extends VisualizationSubscription<double> {
  _MaxVisualizationSubscription(super.config, super.parent);

  @override
  void _applyIncomingUnbufferedValue(double value, Duration engineTime) {
    if (_engineTime == null ||
        value > (_value ?? _config.visualizationType.defaultValue)) {
      _value = value;
      _engineTime = engineTime;
    }
  }

  @override
  bool _renderBufferedValue(Duration renderTime) {
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

      if (_engineTime != null && _value != null) {
        return _setRenderedValue(_value!, renderTime);
      }

      return false;
    }

    var maxValue = samples.first.value;
    for (final sample in samples.skip(1)) {
      if (sample.value > maxValue) {
        maxValue = sample.value;
      }
    }

    return _setRenderedValue(maxValue, renderTime);
  }
}

class _BufferedVisualizationSample<T> {
  final T value;
  final Duration engineTime;

  const _BufferedVisualizationSample({
    required this.value,
    required this.engineTime,
  });
}

class _VisualizationSampleBuffer<T> {
  final Duration maxBufferedDuration;
  final int maxSampleCount;
  final List<_BufferedVisualizationSample<T>> _samples = [];

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

  void add(T value, Duration engineTime) {
    _samples.add(
      _BufferedVisualizationSample<T>(value: value, engineTime: engineTime),
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

  _BufferedVisualizationSample<T>? latestAtOrBefore(Duration engineTime) {
    for (var i = _samples.length - 1; i >= 0; i--) {
      final sample = _samples[i];
      if (sample.engineTime <= engineTime) {
        return sample;
      }
    }

    return null;
  }

  _BufferedVisualizationSample<T>? earliestAfter(Duration engineTime) {
    for (final sample in _samples) {
      if (sample.engineTime > engineTime) {
        return sample;
      }
    }

    return null;
  }

  List<_BufferedVisualizationSample<T>> between({
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
