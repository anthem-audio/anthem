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

import 'package:anthem/visualization/ring_buffer.dart';

/// Estimates transport timing jitter for adaptive visualization buffering.
///
/// This type is intentionally kept out of `visualization.dart`'s export
/// surface. Import it from `package:anthem/visualization/src/...` when direct
/// access is needed for tests or other internal consumers.
///
/// The goal here is to estimate how much wall-clock delivery timing deviates
/// from the engine-time progression visible to the UI. Adaptive subscriptions
/// use the derived delay, margin, and timeout values to decide how far behind
/// real time they should render in order to smooth over transport jitter.
class VisualizationTransportStats {
  static const _historyLength = 120;
  static const _minimumBufferMargin = Duration(milliseconds: 4);
  static const _maximumRecommendedDelay = Duration(milliseconds: 250);
  static const _minimumStallTimeout = Duration(milliseconds: 120);

  final Duration Function() _wallClockNow;
  final _VisualizationTimingWindow _wallIntervalWindow =
      _VisualizationTimingWindow(_historyLength);
  final _VisualizationTimingWindow _engineIntervalWindow =
      _VisualizationTimingWindow(_historyLength);
  final _VisualizationTimingWindow _timingErrorWindow =
      _VisualizationTimingWindow(_historyLength);

  Duration? _lastArrivalTime;
  Duration? _lastEventEngineTime;
  Duration _recommendedDelay = Duration.zero;

  VisualizationTransportStats(this._wallClockNow);

  Duration get recommendedDelay => _recommendedDelay;

  Duration get averageInterval => _engineIntervalWindow.averageInterval;

  Duration get averageWallInterval => _wallIntervalWindow.averageInterval;

  Duration get averageJitter => _timingErrorWindow.averageInterval;

  Duration get p95Jitter => _timingErrorWindow.p95;

  Duration get bufferMargin {
    final halfAverageInterval = Duration(
      microseconds: averageInterval.inMicroseconds ~/ 2,
    );
    return halfAverageInterval > _minimumBufferMargin
        ? halfAverageInterval
        : _minimumBufferMargin;
  }

  Duration get stallTimeout {
    final averageInterval = averageWallInterval > this.averageInterval
        ? averageWallInterval
        : this.averageInterval;
    final delayBasedTimeout = Duration(
      microseconds: recommendedDelay.inMicroseconds * 3,
    );
    final intervalBasedTimeout = Duration(
      microseconds: averageInterval.inMicroseconds * 4,
    );

    final timeout = delayBasedTimeout > intervalBasedTimeout
        ? delayBasedTimeout
        : intervalBasedTimeout;
    return timeout > _minimumStallTimeout ? timeout : _minimumStallTimeout;
  }

  void recordArrival(Duration? eventEngineTime) {
    final now = _wallClockNow();

    if (eventEngineTime == null) {
      return;
    }

    if (_lastArrivalTime != null && _lastEventEngineTime != null) {
      final wallDelta = now - _lastArrivalTime!;
      final engineDelta = eventEngineTime - _lastEventEngineTime!;

      if (engineDelta < Duration.zero) {
        // A backwards engine-time jump indicates a discontinuity, so previous
        // transport timing samples are no longer relevant.
        _reset(eventEngineTime: eventEngineTime, wallTime: now);
        return;
      }

      if (wallDelta > Duration.zero && engineDelta > Duration.zero) {
        // Jitter is measured as the difference between wall-clock progress and
        // engine-time progress for the newest visualization data visible to the
        // UI. This captures both transport jitter and batching cadence.
        final timingError = Duration(
          microseconds: (wallDelta.inMicroseconds - engineDelta.inMicroseconds)
              .abs(),
        );

        _wallIntervalWindow.add(wallDelta);
        _engineIntervalWindow.add(engineDelta);
        _timingErrorWindow.add(timingError);
        _updateRecommendedDelay();
      } else if (engineDelta == Duration.zero) {
        return;
      }
    }

    _lastArrivalTime = now;
    _lastEventEngineTime = eventEngineTime;
  }

  void _reset({required Duration eventEngineTime, required Duration wallTime}) {
    _wallIntervalWindow.clear();
    _engineIntervalWindow.clear();
    _timingErrorWindow.clear();
    _recommendedDelay = Duration.zero;
    _lastArrivalTime = wallTime;
    _lastEventEngineTime = eventEngineTime;
  }

  void _updateRecommendedDelay() {
    // The render delay grows quickly when the observed timing error gets worse
    // so buffered subscriptions can stabilize quickly, but relaxes slowly to
    // avoid bouncing between buffering thresholds.
    final candidate = p95Jitter + averageJitter;
    final clampedCandidate = candidate > _maximumRecommendedDelay
        ? _maximumRecommendedDelay
        : candidate;

    if (clampedCandidate > _recommendedDelay) {
      _recommendedDelay = clampedCandidate;
      return;
    }

    final currentUs = _recommendedDelay.inMicroseconds;
    final candidateUs = clampedCandidate.inMicroseconds;
    final relaxedUs = currentUs + ((candidateUs - currentUs) * 0.1).round();
    _recommendedDelay = Duration(microseconds: relaxedUs < 0 ? 0 : relaxedUs);
  }
}

class _VisualizationTimingWindow {
  final RingBuffer<int> _durations;

  _VisualizationTimingWindow(int sampleCount)
    : _durations = RingBuffer<int>(sampleCount);

  void add(Duration duration) {
    _durations.add(duration.inMicroseconds);
  }

  Duration get averageInterval {
    final values = _durations.values.toList(growable: false);
    if (values.isEmpty) {
      return Duration.zero;
    }

    final total = values.fold<int>(0, (sum, value) => sum + value);
    return Duration(microseconds: (total / values.length).round());
  }

  Duration get p95 {
    final values = _durations.values.toList(growable: false);
    if (values.isEmpty) {
      return Duration.zero;
    }

    final sortedValues = [...values]..sort();

    final index = ((sortedValues.length - 1) * 0.95).floor();
    return Duration(microseconds: sortedValues[index]);
  }

  void clear() {
    _durations.reset();
  }
}
