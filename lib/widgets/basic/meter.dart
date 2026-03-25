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

import 'dart:math' as math;
import 'dart:ui';

import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef StereoMeterValues = ({double left, double right});
typedef MeterGradientStop = ({double db, Color color});
typedef MeterDbToNormalizedPosition = double Function(double db);

double defaultMeterDbToNormalizedPosition(double db) {
  // Visualization updates travel over JSON, which cannot represent -inf. The
  // engine therefore encodes silent meter values as -600 dB on the wire.
  if (db <= -600.0) {
    return 0.0;
  }

  return gainDbToParameterValue(db);
}

class Meter extends StatefulWidget {
  final StereoMeterValues db;
  final Duration timestamp;
  final List<MeterGradientStop>? gradientStops;
  final MeterDbToNormalizedPosition dbToNormalizedPosition;
  final bool noBackground;
  final Duration peakHoldDuration;
  final double peakFallRateNormalizedPerSecond;
  final double peakLineThickness;

  const Meter({
    super.key,
    required this.db,
    required this.timestamp,
    this.gradientStops,
    this.dbToNormalizedPosition = defaultMeterDbToNormalizedPosition,
    this.noBackground = false,
    this.peakHoldDuration = const Duration(milliseconds: 750),
    this.peakFallRateNormalizedPerSecond = 0.8,
    this.peakLineThickness = 1.0,
  });

  static ({List<Color> colors, List<double> stops}) resolveGradient({
    required List<MeterGradientStop> gradientStops,
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
  }) {
    if (gradientStops.length < 2) {
      throw StateError(
        'Meter - resolveMeterGradient: gradientStops must contain at least two points.',
      );
    }

    return (
      colors: List<Color>.unmodifiable(gradientStops.map((stop) => stop.color)),
      stops: List<double>.unmodifiable(
        gradientStops.map((stop) {
          return Meter.dbToNormalizedHeight(stop.db, dbToNormalizedPosition);
        }),
      ),
    );
  }

  static double decayPeakNormalizedHeight({
    required double currentNormalizedHeight,
    required double previousPeakNormalizedHeight,
    required Duration elapsed,
    required double fallRateNormalizedPerSecond,
  }) {
    if (elapsed <= Duration.zero || fallRateNormalizedPerSecond <= 0) {
      return math.max(currentNormalizedHeight, previousPeakNormalizedHeight);
    }

    final fallenNormalized =
        fallRateNormalizedPerSecond *
        (elapsed.inMicroseconds / Duration.microsecondsPerSecond);

    return clampDouble(
      math.max(
        currentNormalizedHeight,
        math.max(0.0, previousPeakNormalizedHeight - fallenNormalized),
      ),
      0.0,
      1.0,
    );
  }

  static double dbToNormalizedHeight(
    double db,
    MeterDbToNormalizedPosition dbToNormalizedPosition,
  ) {
    return Meter.dbToPixelHeight(db, 1.0, dbToNormalizedPosition);
  }

  static double dbToPixelHeight(
    double db,
    double totalMeterHeight,
    MeterDbToNormalizedPosition dbToNormalizedPosition,
  ) {
    return clampDouble(dbToNormalizedPosition(db), 0.0, 1.0) * totalMeterHeight;
  }

  @override
  State<Meter> createState() => _MeterState();
}

class _MeterState extends State<Meter> {
  Duration? _lastTimestamp;
  StereoMeterValues? _lastDb;
  StereoMeterValues _peakNormalizedHeights = (left: 0.0, right: 0.0);
  ({Duration left, Duration right}) _peakTimestamps = (
    left: Duration.zero,
    right: Duration.zero,
  );

  final List<MeterGradientStop> _defaultGradientStops = <MeterGradientStop>[
    (db: double.negativeInfinity, color: AnthemTheme.meter.low),
    (db: 0.0, color: AnthemTheme.meter.high),
    (db: 0.0, color: AnthemTheme.meter.clipping),
    (db: 12.0, color: AnthemTheme.meter.clipping),
  ];

  _ResolvedMeterValues _resolveMeterValues() {
    final currentNormalizedHeights = (
      left: Meter.dbToNormalizedHeight(
        widget.db.left,
        widget.dbToNormalizedPosition,
      ),
      right: Meter.dbToNormalizedHeight(
        widget.db.right,
        widget.dbToNormalizedPosition,
      ),
    );

    if (_lastTimestamp == null ||
        _lastDb == null ||
        widget.timestamp < _lastTimestamp!) {
      _peakNormalizedHeights = currentNormalizedHeights;
      _peakTimestamps = (left: widget.timestamp, right: widget.timestamp);
    } else if (_lastTimestamp != widget.timestamp || _lastDb != widget.db) {
      final leftPeakState = _resolvePeakChannelState(
        currentNormalizedHeight: currentNormalizedHeights.left,
        previousPeakNormalizedHeight: _peakNormalizedHeights.left,
        previousPeakTimestamp: _peakTimestamps.left,
        previousTimestamp: _lastTimestamp!,
        currentTimestamp: widget.timestamp,
      );
      final rightPeakState = _resolvePeakChannelState(
        currentNormalizedHeight: currentNormalizedHeights.right,
        previousPeakNormalizedHeight: _peakNormalizedHeights.right,
        previousPeakTimestamp: _peakTimestamps.right,
        previousTimestamp: _lastTimestamp!,
        currentTimestamp: widget.timestamp,
      );

      _peakNormalizedHeights = (
        left: leftPeakState.normalizedHeight,
        right: rightPeakState.normalizedHeight,
      );
      _peakTimestamps = (
        left: leftPeakState.peakTimestamp,
        right: rightPeakState.peakTimestamp,
      );
    } else {
      _peakNormalizedHeights = (
        left: math.max(
          _peakNormalizedHeights.left,
          currentNormalizedHeights.left,
        ),
        right: math.max(
          _peakNormalizedHeights.right,
          currentNormalizedHeights.right,
        ),
      );
    }

    _lastTimestamp = widget.timestamp;
    _lastDb = widget.db;

    return _ResolvedMeterValues(
      currentNormalized: currentNormalizedHeights,
      peakNormalized: _peakNormalizedHeights,
    );
  }

  _PeakChannelState _resolvePeakChannelState({
    required double currentNormalizedHeight,
    required double previousPeakNormalizedHeight,
    required Duration previousPeakTimestamp,
    required Duration previousTimestamp,
    required Duration currentTimestamp,
  }) {
    if (currentNormalizedHeight > previousPeakNormalizedHeight) {
      return _PeakChannelState(
        normalizedHeight: currentNormalizedHeight,
        peakTimestamp: currentTimestamp,
      );
    }

    final holdEndTimestamp = previousPeakTimestamp + widget.peakHoldDuration;
    if (currentTimestamp <= holdEndTimestamp) {
      return _PeakChannelState(
        normalizedHeight: previousPeakNormalizedHeight,
        peakTimestamp: previousPeakTimestamp,
      );
    }

    final fallStartTimestamp = previousTimestamp > holdEndTimestamp
        ? previousTimestamp
        : holdEndTimestamp;

    return _PeakChannelState(
      normalizedHeight: Meter.decayPeakNormalizedHeight(
        currentNormalizedHeight: currentNormalizedHeight,
        previousPeakNormalizedHeight: previousPeakNormalizedHeight,
        elapsed: currentTimestamp - fallStartTimestamp,
        fallRateNormalizedPerSecond: widget.peakFallRateNormalizedPerSecond,
      ),
      peakTimestamp: previousPeakTimestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final meterValues = _resolveMeterValues();
    final gradient = Meter.resolveGradient(
      gradientStops: widget.gradientStops ?? _defaultGradientStops,
      dbToNormalizedPosition: widget.dbToNormalizedPosition,
    );

    return CustomPaint(
      painter: MeterPainter(
        value: meterValues.currentNormalized,
        peak: meterValues.peakNormalized,
        gradientColors: gradient.colors,
        gradientStopPositions: gradient.stops,
        backgroundTrackColor: AnthemTheme.panel.accent,
        noBackground: widget.noBackground,
        peakLineThickness: widget.peakLineThickness,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class MeterPainter extends CustomPainter {
  /// The current normalized value for each channel.
  final StereoMeterValues value;

  /// The normalized peak value for each channel.
  final StereoMeterValues peak;

  final List<Color> gradientColors;
  final List<double> gradientStopPositions;
  final Color backgroundTrackColor;
  final bool noBackground;
  final double peakLineThickness;

  const MeterPainter({
    required this.value,
    required this.peak,
    required this.gradientColors,
    required this.gradientStopPositions,
    required this.backgroundTrackColor,
    this.noBackground = false,
    this.peakLineThickness = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    const barrierWidth = 1.0;
    final channelWidth = math.max(0.0, (size.width - barrierWidth) / 2);
    if (channelWidth <= 0) {
      return;
    }

    final leftRect = Rect.fromLTWH(0, 0, channelWidth, size.height);
    final rightRect = Rect.fromLTWH(
      channelWidth + barrierWidth,
      0,
      channelWidth,
      size.height,
    );

    _paintChannel(canvas, leftRect, value.left, peak.left);
    _paintChannel(canvas, rightRect, value.right, peak.right);
  }

  void _paintChannel(
    Canvas canvas,
    Rect channelRect,
    double valueNormalized,
    double peakNormalized,
  ) {
    if (!noBackground) {
      canvas.drawRect(channelRect, Paint()..color = backgroundTrackColor);
    }

    final shaderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: gradientColors,
        stops: gradientStopPositions,
      ).createShader(channelRect);
    final clampedValue = clampDouble(valueNormalized, 0.0, 1.0);
    final activeHeight = channelRect.height * clampedValue;

    if (activeHeight > 0) {
      final activeRect = Rect.fromLTWH(
        channelRect.left,
        channelRect.bottom - activeHeight,
        channelRect.width,
        activeHeight,
      );

      canvas.drawRect(activeRect, shaderPaint);
    }

    final clampedPeak = clampDouble(peakNormalized, 0.0, 1.0);
    if (clampedPeak <= 0) {
      return;
    }

    final clampedLineThickness = clampDouble(
      peakLineThickness,
      0.0,
      channelRect.height,
    );
    if (clampedLineThickness <= 0) {
      return;
    }

    final peakPixelHeight = channelRect.height * clampedPeak;
    final peakTop = clampDouble(
      channelRect.bottom - peakPixelHeight - clampedLineThickness,
      channelRect.top,
      channelRect.bottom - clampedLineThickness,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        channelRect.left,
        peakTop,
        channelRect.width,
        clampedLineThickness,
      ),
      shaderPaint,
    );
  }

  @override
  bool shouldRepaint(MeterPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.peak != peak ||
        !listEquals(oldDelegate.gradientColors, gradientColors) ||
        !listEquals(oldDelegate.gradientStopPositions, gradientStopPositions) ||
        oldDelegate.backgroundTrackColor != backgroundTrackColor ||
        oldDelegate.noBackground != noBackground ||
        oldDelegate.peakLineThickness != peakLineThickness;
  }

  @override
  bool shouldRebuildSemantics(MeterPainter oldDelegate) => false;
}

class _ResolvedMeterValues {
  final StereoMeterValues currentNormalized;
  final StereoMeterValues peakNormalized;

  const _ResolvedMeterValues({
    required this.currentNormalized,
    required this.peakNormalized,
  });
}

class _PeakChannelState {
  final double normalizedHeight;
  final Duration peakTimestamp;

  const _PeakChannelState({
    required this.normalizedHeight,
    required this.peakTimestamp,
  });
}
