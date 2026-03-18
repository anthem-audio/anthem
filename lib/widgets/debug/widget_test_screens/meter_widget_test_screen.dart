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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/meter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class MeterWidgetTestScreen extends StatefulWidget {
  const MeterWidgetTestScreen({super.key});

  @override
  State<MeterWidgetTestScreen> createState() => _MeterWidgetTestScreenState();
}

class _MeterWidgetTestScreenState extends State<MeterWidgetTestScreen>
    with SingleTickerProviderStateMixin {
  static const _meterBarWidth = 6.0;
  static const _meterBarrierWidth = 1.0;
  static const _meterWidth = _meterBarWidth * 2 + _meterBarrierWidth;
  static const _readoutWidth = 76.0;
  static const _animatedMeterPeakFallRateNormalizedPerSecond = 130.0 / 164.0;

  late final Ticker _ticker;
  Duration _engineTime = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  bool _isRunning = true;

  static const _animatedGradientStops = <MeterGradientStop>[
    (db: -180.0, color: Color(0xFF38D078)),
    (db: 0.0, color: Color(0xFFE3D54F)),
    (db: 0.0, color: Color(0xFFE85E47)),
    (db: 6.0, color: Color(0xFFE85E47)),
  ];

  static const _coolGradientStops = <MeterGradientStop>[
    (db: -180.0, color: Color(0xFF4AB8FF)),
    (db: 0.0, color: Color(0xFF55E39F)),
    (db: 0.0, color: Color(0xFF3ED18C)),
    (db: 6.0, color: Color(0xFF3ED18C)),
  ];

  static const _hotGradientStops = <MeterGradientStop>[
    (db: -180.0, color: Color(0xFF74F06A)),
    (db: 0.0, color: Color(0xFFE8C24F)),
    (db: 0.0, color: Color(0xFFE04A3A)),
    (db: 6.0, color: Color(0xFFE04A3A)),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleTick(Duration elapsed) {
    if (!_isRunning) {
      _lastElapsed = elapsed;
      return;
    }

    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;

    if (delta <= Duration.zero) {
      return;
    }

    setState(() {
      _engineTime += delta;
    });
  }

  StereoMeterValues _animatedDbAt(Duration time) {
    final seconds = time.inMicroseconds / Duration.microsecondsPerSecond;

    final leftNorm = clampDouble(
      0.08 +
          0.5 * (0.5 + 0.5 * math.sin(seconds * 3.1)) +
          0.3 * (0.5 + 0.5 * math.sin(seconds * 9.4)) +
          _spikeBoost(seconds: seconds, seed: 0.17),
      0.0,
      1.0,
    );
    final rightNorm = clampDouble(
      0.06 +
          0.52 * (0.5 + 0.5 * math.sin(seconds * 2.6 + 0.7)) +
          0.26 * (0.5 + 0.5 * math.sin(seconds * 7.6 + 1.3)) +
          _spikeBoost(seconds: seconds, seed: 0.61),
      0.0,
      1.0,
    );

    return (left: _normalizedToDb(leftNorm), right: _normalizedToDb(rightNorm));
  }

  double _spikeBoost({required double seconds, required double seed}) {
    const intervalSeconds = 2.8;
    const spikeDurationSeconds = 0.18;

    final bucket = (seconds / intervalSeconds).floor();
    final bucketStart = bucket * intervalSeconds;
    final positionInBucket = seconds - bucketStart;
    final randomValue = _pseudoRandom(bucket + seed * 1000);

    if (randomValue < 0.72 || positionInBucket > spikeDurationSeconds) {
      return 0.0;
    }

    final progress = positionInBucket / spikeDurationSeconds;
    final envelope = math.sin(progress * math.pi);
    return envelope *
        (0.18 + 0.22 * _pseudoRandom(bucket + 37.0 + seed * 1000));
  }

  double _pseudoRandom(double value) {
    final x = math.sin(value * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  double _normalizedToDb(double value) {
    return lerpDouble(-72.0, 3.0, value)!;
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AnthemTheme.panel.backgroundDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AnthemTheme.panel.border),
      ),
      child: child,
    );
  }

  Widget _buildStaticMeter({
    required String label,
    required String valueLabel,
    required StereoMeterValues db,
    required List<MeterGradientStop> gradientStops,
  }) {
    return SizedBox(
      width: 78,
      child: Column(
        spacing: 8,
        children: [
          Text(
            label,
            style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            width: _meterWidth,
            height: 132,
            child: Meter(
              db: db,
              timestamp: _engineTime,
              gradientStops: gradientStops,
            ),
          ),
          Text(
            valueLabel,
            style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animatedDb = _animatedDbAt(_engineTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Animated meter',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                spacing: 24,
                children: [
                  Column(
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: _meterWidth,
                        height: 164,
                        child: Meter(
                          db: animatedDb,
                          timestamp: _engineTime,
                          gradientStops: _animatedGradientStops,
                          peakFallRateNormalizedPerSecond:
                              _animatedMeterPeakFallRateNormalizedPerSecond,
                        ),
                      ),
                      SizedBox(
                        width: _readoutWidth,
                        child: Text(
                          'L ${animatedDb.left.toStringAsFixed(1)} dB',
                          style: TextStyle(
                            color: AnthemTheme.text.main,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: _readoutWidth,
                        child: Text(
                          'R ${animatedDb.right.toStringAsFixed(1)} dB',
                          style: TextStyle(
                            color: AnthemTheme.text.main,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        Text(
                          'Engine time: ${(_engineTime.inMilliseconds / 1000).toStringAsFixed(2)} s',
                          style: TextStyle(
                            color: AnthemTheme.text.main,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'The meter is driven by synthetic stereo dB values and advances in engine-time, not wall-clock UI time.',
                          style: TextStyle(
                            color: AnthemTheme.text.main,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          spacing: 8,
                          children: [
                            SizedBox(
                              width: 112,
                              height: 30,
                              child: Button(
                                text: _isRunning ? 'Pause' : 'Resume',
                                onPress: () {
                                  setState(() {
                                    _isRunning = !_isRunning;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              height: 30,
                              child: Button(
                                text: 'Reset time',
                                onPress: () {
                                  setState(() {
                                    _engineTime = Duration.zero;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          'Static reference states',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        _buildPanel(
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _buildStaticMeter(
                label: 'Low',
                valueLabel: '-72 / -66',
                db: (left: -72.0, right: -66.0),
                gradientStops: _coolGradientStops,
              ),
              _buildStaticMeter(
                label: 'Nominal',
                valueLabel: '-24 / -18',
                db: (left: -24.0, right: -18.0),
                gradientStops: _animatedGradientStops,
              ),
              _buildStaticMeter(
                label: 'Hot',
                valueLabel: '-3 / +1.5',
                db: (left: -3.0, right: 1.5),
                gradientStops: _hotGradientStops,
              ),
              _buildStaticMeter(
                label: 'Clipped',
                valueLabel: '+6 / +6',
                db: (left: 6.0, right: 6.0),
                gradientStops: _hotGradientStops,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
