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
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

typedef StereoMeterValues = ({double left, double right});
typedef StereoMeterConfigs = ({
  VisualizationSubscriptionConfig<double> left,
  VisualizationSubscriptionConfig<double> right,
});
typedef MeterGradientStop = ({double db, Color color});
typedef MeterDbToNormalizedPosition = double Function(double db);

final List<MeterGradientStop> _defaultMeterGradientStops = <MeterGradientStop>[
  (db: double.negativeInfinity, color: AnthemTheme.meter.low),
  (db: 0.0, color: AnthemTheme.meter.high),
  (db: 0.0, color: AnthemTheme.meter.clipping),
  (db: 12.0, color: AnthemTheme.meter.clipping),
];

double defaultMeterDbToNormalizedPosition(double db) {
  // Visualization updates travel over JSON, which cannot represent -inf. The
  // engine therefore encodes silent meter values as -600 dB on the wire.
  if (db <= -600.0) {
    return 0.0;
  }

  return gainDbToParameterValue(db);
}

/// Painter-ready meter state derived from the latest stereo visualization
/// values and peak-hold tracking.
class MeterSnapshot {
  /// The normalized fill height for each stereo channel.
  final StereoMeterValues currentNormalized;

  /// The normalized peak indicator height for each stereo channel.
  final StereoMeterValues peakNormalized;

  const MeterSnapshot({
    required this.currentNormalized,
    required this.peakNormalized,
  });

  /// A silent snapshot used before the meter has received any visualization
  /// data.
  static final empty = MeterSnapshot(
    currentNormalized: (left: 0.0, right: 0.0),
    peakNormalized: (left: 0.0, right: 0.0),
  );

  @override
  operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is MeterSnapshot &&
        other.currentNormalized == currentNormalized &&
        other.peakNormalized == peakNormalized;
  }

  @override
  int get hashCode => Object.hash(currentNormalized, peakNormalized);
}

class Meter extends StatefulWidget {
  final StereoMeterConfigs configs;
  final List<MeterGradientStop>? gradientStops;
  final MeterDbToNormalizedPosition dbToNormalizedPosition;
  final bool noBackground;
  final Duration peakHoldDuration;
  final double peakFallRateNormalizedPerSecond;
  final double peakLineThickness;

  const Meter({
    super.key,
    required this.configs,
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
  late final _MeterController _controller;

  @override
  void initState() {
    super.initState();

    _controller = _MeterController(
      visualizationProvider: Provider.of<ProjectModel>(
        context,
        listen: false,
      ).visualizationProvider,
      configs: widget.configs,
      dbToNormalizedPosition: widget.dbToNormalizedPosition,
      peakHoldDuration: widget.peakHoldDuration,
      peakFallRateNormalizedPerSecond: widget.peakFallRateNormalizedPerSecond,
    );
  }

  @override
  void didUpdateWidget(covariant Meter oldWidget) {
    super.didUpdateWidget(oldWidget);

    _controller.update(
      configs: widget.configs,
      dbToNormalizedPosition: widget.dbToNormalizedPosition,
      peakHoldDuration: widget.peakHoldDuration,
      peakFallRateNormalizedPerSecond: widget.peakFallRateNormalizedPerSecond,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = Meter.resolveGradient(
      gradientStops: widget.gradientStops ?? _defaultMeterGradientStops,
      dbToNormalizedPosition: widget.dbToNormalizedPosition,
    );

    return CustomPaint(
      painter: MeterPainter.fromListenable(
        snapshotListenable: _controller,
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
  final MeterSnapshot? _snapshot;
  final ValueListenable<MeterSnapshot>? _snapshotListenable;

  final List<Color> gradientColors;
  final List<double> gradientStopPositions;
  final Color backgroundTrackColor;
  final bool noBackground;
  final double peakLineThickness;

  MeterPainter({
    required MeterSnapshot snapshot,
    required this.gradientColors,
    required this.gradientStopPositions,
    required this.backgroundTrackColor,
    this.noBackground = false,
    this.peakLineThickness = 1.0,
  }) : _snapshot = snapshot,
       _snapshotListenable = null;

  MeterPainter.fromListenable({
    required ValueListenable<MeterSnapshot> snapshotListenable,
    required this.gradientColors,
    required this.gradientStopPositions,
    required this.backgroundTrackColor,
    this.noBackground = false,
    this.peakLineThickness = 1.0,
  }) : _snapshot = null,
       _snapshotListenable = snapshotListenable,
       super(repaint: snapshotListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = _snapshotListenable?.value ?? _snapshot!;

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

    _paintChannel(
      canvas,
      leftRect,
      snapshot.currentNormalized.left,
      snapshot.peakNormalized.left,
    );
    _paintChannel(
      canvas,
      rightRect,
      snapshot.currentNormalized.right,
      snapshot.peakNormalized.right,
    );
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
    return oldDelegate._snapshot != _snapshot ||
        oldDelegate._snapshotListenable != _snapshotListenable ||
        !listEquals(oldDelegate.gradientColors, gradientColors) ||
        !listEquals(oldDelegate.gradientStopPositions, gradientStopPositions) ||
        oldDelegate.backgroundTrackColor != backgroundTrackColor ||
        oldDelegate.noBackground != noBackground ||
        oldDelegate.peakLineThickness != peakLineThickness;
  }

  @override
  bool shouldRebuildSemantics(MeterPainter oldDelegate) => false;
}

class MeterValueTracker {
  MeterDbToNormalizedPosition _dbToNormalizedPosition;
  Duration _peakHoldDuration;
  double _peakFallRateNormalizedPerSecond;

  Duration? _lastTimestamp;
  StereoMeterValues? _lastDb;
  StereoMeterValues _peakNormalizedHeights = (left: 0.0, right: 0.0);
  ({Duration left, Duration right}) _peakTimestamps = (
    left: Duration.zero,
    right: Duration.zero,
  );

  MeterValueTracker({
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
    required Duration peakHoldDuration,
    required double peakFallRateNormalizedPerSecond,
  }) : _dbToNormalizedPosition = dbToNormalizedPosition,
       _peakHoldDuration = peakHoldDuration,
       _peakFallRateNormalizedPerSecond = peakFallRateNormalizedPerSecond;

  void updateConfig({
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
    required Duration peakHoldDuration,
    required double peakFallRateNormalizedPerSecond,
  }) {
    _dbToNormalizedPosition = dbToNormalizedPosition;
    _peakHoldDuration = peakHoldDuration;
    _peakFallRateNormalizedPerSecond = peakFallRateNormalizedPerSecond;
  }

  MeterSnapshot resolve({
    required StereoMeterValues db,
    required Duration timestamp,
  }) {
    final currentNormalizedHeights = (
      left: Meter.dbToNormalizedHeight(db.left, _dbToNormalizedPosition),
      right: Meter.dbToNormalizedHeight(db.right, _dbToNormalizedPosition),
    );

    if (_lastTimestamp == null ||
        _lastDb == null ||
        timestamp < _lastTimestamp!) {
      _peakNormalizedHeights = currentNormalizedHeights;
      _peakTimestamps = (left: timestamp, right: timestamp);
    } else if (_lastTimestamp != timestamp || _lastDb != db) {
      final leftPeakState = _resolvePeakChannelState(
        currentNormalizedHeight: currentNormalizedHeights.left,
        previousPeakNormalizedHeight: _peakNormalizedHeights.left,
        previousPeakTimestamp: _peakTimestamps.left,
        previousTimestamp: _lastTimestamp!,
        currentTimestamp: timestamp,
      );
      final rightPeakState = _resolvePeakChannelState(
        currentNormalizedHeight: currentNormalizedHeights.right,
        previousPeakNormalizedHeight: _peakNormalizedHeights.right,
        previousPeakTimestamp: _peakTimestamps.right,
        previousTimestamp: _lastTimestamp!,
        currentTimestamp: timestamp,
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

    _lastTimestamp = timestamp;
    _lastDb = db;

    return MeterSnapshot(
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

    final holdEndTimestamp = previousPeakTimestamp + _peakHoldDuration;
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
        fallRateNormalizedPerSecond: _peakFallRateNormalizedPerSecond,
      ),
      peakTimestamp: previousPeakTimestamp,
    );
  }
}

class _MeterController extends ChangeNotifier
    implements ValueListenable<MeterSnapshot> {
  final MultiVisualizationSubscriptionController<double>
  _visualizationController;
  final MeterValueTracker _valueTracker;

  MeterSnapshot _snapshot = MeterSnapshot.empty;

  _MeterController({
    required VisualizationProvider visualizationProvider,
    required StereoMeterConfigs configs,
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
    required Duration peakHoldDuration,
    required double peakFallRateNormalizedPerSecond,
  }) : _visualizationController =
           MultiVisualizationSubscriptionController<double>(
             visualizationProvider: visualizationProvider,
             configs: _configsToList(configs),
           ),
       _valueTracker = MeterValueTracker(
         dbToNormalizedPosition: dbToNormalizedPosition,
         peakHoldDuration: peakHoldDuration,
         peakFallRateNormalizedPerSecond: peakFallRateNormalizedPerSecond,
       ) {
    _visualizationController.addListener(_handleVisualizationControllerChanged);
    _syncSnapshot(notify: false);
  }

  @override
  MeterSnapshot get value => _snapshot;

  void update({
    required StereoMeterConfigs configs,
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
    required Duration peakHoldDuration,
    required double peakFallRateNormalizedPerSecond,
  }) {
    final previousSnapshot = _snapshot;

    _valueTracker.updateConfig(
      dbToNormalizedPosition: dbToNormalizedPosition,
      peakHoldDuration: peakHoldDuration,
      peakFallRateNormalizedPerSecond: peakFallRateNormalizedPerSecond,
    );

    _visualizationController.removeListener(
      _handleVisualizationControllerChanged,
    );
    _visualizationController.update(configs: _configsToList(configs));
    _visualizationController.addListener(_handleVisualizationControllerChanged);

    _syncSnapshot(notify: false);

    if (_snapshot != previousSnapshot) {
      notifyListeners();
    }
  }

  void _handleVisualizationControllerChanged() {
    _syncSnapshot();
  }

  static List<VisualizationSubscriptionConfig<double>> _configsToList(
    StereoMeterConfigs configs,
  ) {
    return <VisualizationSubscriptionConfig<double>>[
      configs.left,
      configs.right,
    ];
  }

  ({StereoMeterValues db, Duration timestamp}) _resolveMeterInput() {
    final values = _visualizationController.values;
    final engineTimes = _visualizationController.engineTimes;
    final hasStereoValues = values.length >= 2;
    final hasFullTimestampSet =
        engineTimes.length >= 2 &&
        engineTimes[0] != null &&
        engineTimes[1] != null;

    if (!hasStereoValues || !hasFullTimestampSet) {
      return (
        db: (left: double.negativeInfinity, right: double.negativeInfinity),
        timestamp: Duration.zero,
      );
    }

    final leftTime = engineTimes[0]!;
    final rightTime = engineTimes[1]!;

    return (
      db: (left: values[0], right: values[1]),
      timestamp: leftTime.compareTo(rightTime) >= 0 ? leftTime : rightTime,
    );
  }

  void _syncSnapshot({bool notify = true}) {
    final input = _resolveMeterInput();
    final nextSnapshot = _valueTracker.resolve(
      db: input.db,
      timestamp: input.timestamp,
    );

    if (nextSnapshot == _snapshot) {
      return;
    }

    _snapshot = nextSnapshot;

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _visualizationController.removeListener(
      _handleVisualizationControllerChanged,
    );
    _visualizationController.dispose();
    super.dispose();
  }
}

class _PeakChannelState {
  final double normalizedHeight;
  final Duration peakTimestamp;

  const _PeakChannelState({
    required this.normalizedHeight,
    required this.peakTimestamp,
  });
}
