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
typedef StereoMeterTimestamps = ({Duration left, Duration right});
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

double _estimatedVisualizationSamplesPerSecond() {
  var estimatedSamplesPerSecond = 60.0;

  for (final display in PlatformDispatcher.instance.displays) {
    final refreshRate = display.refreshRate;
    if (refreshRate.isFinite && refreshRate > estimatedSamplesPerSecond) {
      estimatedSamplesPerSecond = refreshRate;
    }
  }

  return estimatedSamplesPerSecond;
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
    required MeterSnapshot this._snapshot,
    required this.gradientColors,
    required this.gradientStopPositions,
    required this.backgroundTrackColor,
    this.noBackground = false,
    this.peakLineThickness = 1.0,
  }) : _snapshotListenable = null;

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

  final double _estimatedSamplesPerSecond;
  late final _MeterPeakChannelTracker _leftPeakTracker;
  late final _MeterPeakChannelTracker _rightPeakTracker;

  MeterValueTracker({
    required this._dbToNormalizedPosition,
    required this._peakHoldDuration,
    required this._peakFallRateNormalizedPerSecond,
    double estimatedSamplesPerSecond = 60.0,
  }) : _estimatedSamplesPerSecond =
           estimatedSamplesPerSecond.isFinite && estimatedSamplesPerSecond > 0
           ? estimatedSamplesPerSecond
           : 60.0 {
    final initialHistoryCapacity = estimateHistoryCapacity(
      peakHoldDuration: _peakHoldDuration,
      estimatedSamplesPerSecond: _estimatedSamplesPerSecond,
    );

    _leftPeakTracker = _MeterPeakChannelTracker(
      initialHistoryCapacity: initialHistoryCapacity,
      peakHoldDuration: _peakHoldDuration,
    );
    _rightPeakTracker = _MeterPeakChannelTracker(
      initialHistoryCapacity: initialHistoryCapacity,
      peakHoldDuration: _peakHoldDuration,
    );
  }

  @visibleForTesting
  static int estimateHistoryCapacity({
    required Duration peakHoldDuration,
    required double estimatedSamplesPerSecond,
  }) {
    final effectiveSamplesPerSecond =
        estimatedSamplesPerSecond.isFinite && estimatedSamplesPerSecond > 0
        ? estimatedSamplesPerSecond
        : 60.0;
    final holdDurationSeconds =
        math.max(0, peakHoldDuration.inMicroseconds) /
        Duration.microsecondsPerSecond;

    return math.max(
      1,
      (holdDurationSeconds * effectiveSamplesPerSecond * 1.5).ceil(),
    );
  }

  void updateConfig({
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
    required Duration peakHoldDuration,
    required double peakFallRateNormalizedPerSecond,
  }) {
    final didMappingChange = _dbToNormalizedPosition != dbToNormalizedPosition;
    final didPeakHoldDurationChange = _peakHoldDuration != peakHoldDuration;

    _dbToNormalizedPosition = dbToNormalizedPosition;
    _peakHoldDuration = peakHoldDuration;
    _peakFallRateNormalizedPerSecond = peakFallRateNormalizedPerSecond;

    if (didPeakHoldDurationChange) {
      final requiredHistoryCapacity = estimateHistoryCapacity(
        peakHoldDuration: peakHoldDuration,
        estimatedSamplesPerSecond: _estimatedSamplesPerSecond,
      );
      _leftPeakTracker.updateHistoryConfig(
        peakHoldDuration: peakHoldDuration,
        requiredCapacity: requiredHistoryCapacity,
      );
      _rightPeakTracker.updateHistoryConfig(
        peakHoldDuration: peakHoldDuration,
        requiredCapacity: requiredHistoryCapacity,
      );
    } else if (didMappingChange) {
      _leftPeakTracker.reset();
      _rightPeakTracker.reset();
    }
  }

  MeterSnapshot resolve({
    required StereoMeterValues db,
    required StereoMeterTimestamps timestamps,
  }) {
    final currentNormalizedHeights = (
      left: Meter.dbToNormalizedHeight(db.left, _dbToNormalizedPosition),
      right: Meter.dbToNormalizedHeight(db.right, _dbToNormalizedPosition),
    );

    final peakNormalizedHeights = (
      left: _leftPeakTracker.resolve(
        currentNormalizedHeight: currentNormalizedHeights.left,
        timestamp: timestamps.left,
        peakFallRateNormalizedPerSecond: _peakFallRateNormalizedPerSecond,
      ),
      right: _rightPeakTracker.resolve(
        currentNormalizedHeight: currentNormalizedHeights.right,
        timestamp: timestamps.right,
        peakFallRateNormalizedPerSecond: _peakFallRateNormalizedPerSecond,
      ),
    );

    return MeterSnapshot(
      currentNormalized: currentNormalizedHeights,
      peakNormalized: peakNormalizedHeights,
    );
  }
}

class _MeterPeakChannelTracker {
  final _MeterSampleHistory _history;

  double _floatingPeakNormalizedHeight = 0.0;
  double? _lastTimestampMicroseconds;

  _MeterPeakChannelTracker({
    required int initialHistoryCapacity,
    required Duration peakHoldDuration,
  }) : _history = _MeterSampleHistory(
         initialCapacity: initialHistoryCapacity,
         retentionDuration: peakHoldDuration,
       );

  double resolve({
    required double currentNormalizedHeight,
    required Duration timestamp,
    required double peakFallRateNormalizedPerSecond,
  }) {
    final timestampMicroseconds = timestamp.inMicroseconds.toDouble();

    if (_lastTimestampMicroseconds != null &&
        timestampMicroseconds < _lastTimestampMicroseconds!) {
      reset();
    }

    _history.add(timestampMicroseconds, currentNormalizedHeight);
    final actualPeakNormalizedHeight = _history.maximumNormalizedHeight;

    if (_lastTimestampMicroseconds == null) {
      _floatingPeakNormalizedHeight = actualPeakNormalizedHeight;
    } else {
      _floatingPeakNormalizedHeight = _decayToward(
        targetNormalizedHeight: actualPeakNormalizedHeight,
        elapsedMicroseconds:
            timestampMicroseconds - _lastTimestampMicroseconds!,
        fallRateNormalizedPerSecond: peakFallRateNormalizedPerSecond,
      );
    }

    _lastTimestampMicroseconds = timestampMicroseconds;
    return _floatingPeakNormalizedHeight;
  }

  double _decayToward({
    required double targetNormalizedHeight,
    required double elapsedMicroseconds,
    required double fallRateNormalizedPerSecond,
  }) {
    final fallenNormalized =
        math.max(0.0, fallRateNormalizedPerSecond) *
        (math.max(0.0, elapsedMicroseconds) / Duration.microsecondsPerSecond);

    return clampDouble(
      math.max(
        targetNormalizedHeight,
        _floatingPeakNormalizedHeight - fallenNormalized,
      ),
      0.0,
      1.0,
    );
  }

  void updateHistoryConfig({
    required Duration peakHoldDuration,
    required int requiredCapacity,
  }) {
    _history.updateRetentionDuration(peakHoldDuration);
    _history.ensureCapacity(requiredCapacity);
    reset();
  }

  void reset() {
    _history.clear();
    _floatingPeakNormalizedHeight = 0.0;
    _lastTimestampMicroseconds = null;
  }
}

/// A growable circular history containing every meter sample received within
/// a configured retention duration.
///
/// Samples are pruned by timestamp before each insertion. Initial capacity is
/// estimated from the display refresh rate; the buffer doubles when necessary
/// to accommodate timer jitter or bunched updates and never contracts.
class _MeterSampleHistory {
  static const _entryWidth = 2;

  double _retentionDurationMicroseconds;
  Float64List _buffer;
  int _start = 0;
  int _length = 0;

  _MeterSampleHistory({
    required int initialCapacity,
    required Duration retentionDuration,
  }) : _retentionDurationMicroseconds = _durationToMicroseconds(
         retentionDuration,
       ),
       _buffer = Float64List(math.max(1, initialCapacity) * _entryWidth);

  int get _capacity => _buffer.length ~/ _entryWidth;
  bool get isNotEmpty => _length > 0;

  double get firstTimestampMicroseconds => _timestampAt(0);

  double get maximumNormalizedHeight {
    if (!isNotEmpty) {
      throw StateError('Cannot get the maximum of an empty meter history.');
    }

    var maximumNormalizedHeight = _valueAt(0);

    for (var i = 1; i < _length; i++) {
      maximumNormalizedHeight = math.max(maximumNormalizedHeight, _valueAt(i));
    }

    return maximumNormalizedHeight;
  }

  void add(double timestampMicroseconds, double normalizedHeight) {
    final cutoffMicroseconds =
        timestampMicroseconds - _retentionDurationMicroseconds;
    while (isNotEmpty && firstTimestampMicroseconds <= cutoffMicroseconds) {
      _removeFirst();
    }

    ensureCapacity(_length + 1);

    final physicalIndex = (_start + _length) % _capacity;
    final fieldIndex = physicalIndex * _entryWidth;
    _buffer[fieldIndex] = timestampMicroseconds;
    _buffer[fieldIndex + 1] = normalizedHeight;
    _length++;
  }

  void updateRetentionDuration(Duration retentionDuration) {
    _retentionDurationMicroseconds = _durationToMicroseconds(retentionDuration);
  }

  void _removeFirst() {
    if (!isNotEmpty) {
      return;
    }

    _start = (_start + 1) % _capacity;
    _length--;
  }

  void ensureCapacity(int requiredCapacity) {
    if (requiredCapacity <= _capacity) {
      return;
    }

    var nextCapacity = _capacity;
    while (nextCapacity < requiredCapacity) {
      nextCapacity *= 2;
    }

    final nextBuffer = Float64List(nextCapacity * _entryWidth);
    for (var i = 0; i < _length; i++) {
      final nextFieldIndex = i * _entryWidth;
      nextBuffer[nextFieldIndex] = _timestampAt(i);
      nextBuffer[nextFieldIndex + 1] = _valueAt(i);
    }

    _buffer = nextBuffer;
    _start = 0;
  }

  void clear() {
    _start = 0;
    _length = 0;
  }

  int _physicalIndex(int logicalIndex) => (_start + logicalIndex) % _capacity;

  double _timestampAt(int logicalIndex) =>
      _buffer[_physicalIndex(logicalIndex) * _entryWidth];

  double _valueAt(int logicalIndex) =>
      _buffer[_physicalIndex(logicalIndex) * _entryWidth + 1];

  static double _durationToMicroseconds(Duration duration) =>
      math.max(0, duration.inMicroseconds).toDouble();
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
         estimatedSamplesPerSecond: _estimatedVisualizationSamplesPerSecond(),
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

  ({StereoMeterValues db, StereoMeterTimestamps timestamps})
  _resolveMeterInput() {
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
        timestamps: (left: Duration.zero, right: Duration.zero),
      );
    }

    return (
      db: (left: values[0], right: values[1]),
      timestamps: (left: engineTimes[0]!, right: engineTimes[1]!),
    );
  }

  void _syncSnapshot({bool notify = true}) {
    final input = _resolveMeterInput();
    final nextSnapshot = _valueTracker.resolve(
      db: input.db,
      timestamps: input.timestamps,
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
