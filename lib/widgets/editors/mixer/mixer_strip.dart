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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/controls/slider.dart';
import 'package:anthem/widgets/basic/meter.dart';
import 'package:anthem/widgets/basic/meter_scale.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

const mixerStripWidth = 78.0;
const borderWidth = 2.0;
const mixerStripTotalWidth = mixerStripWidth + borderWidth;

const _baseHeaderHeight = 32.0;
const _groupHeaderAddonHeight = 6.0;

Widget _spacer() => Container(height: 1, color: AnthemTheme.panel.border);

class MixerStrip extends StatefulObserverWidget {
  final Id trackId;
  final bool hasStartBorder;
  final bool hasEndBorder;
  final int maxTrackDepth; // The depth of the most-nested track

  const MixerStrip({
    super.key,
    required this.trackId,
    required this.hasStartBorder,
    required this.hasEndBorder,
    required this.maxTrackDepth,
  });

  @override
  State<MixerStrip> createState() => _MixerStripState();
}

class _MixerStripState extends State<MixerStrip> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final track = project.tracks[widget.trackId]!;

    var width = mixerStripWidth;
    if (widget.hasStartBorder) width += borderWidth;
    if (widget.hasEndBorder) width += borderWidth;

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          right: widget.hasEndBorder
              ? .new(color: AnthemTheme.panel.border, width: borderWidth)
              : .none,
        ),
        color: AnthemTheme.panel.accent,
      ),
      child: Column(
        children: [
          _Header(
            track: track,
            maxDepth: widget.maxTrackDepth,
            hasStartBorder: widget.hasStartBorder,
          ),
          _spacer(),
          // This provides a left-hand-side border if necessary
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: widget.hasStartBorder
                      ? .new(
                          color: AnthemTheme.panel.border,
                          width: borderWidth,
                        )
                      : .none,
                ),
              ),
              child: Column(
                children: [
                  Expanded(child: SizedBox()),
                  _spacer(),
                  _MeterSection(track: track),
                  _spacer(),
                  Container(
                    height: _groupHeaderAddonHeight,
                    color: track.color.colorShifter.baseColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessObserverWidget {
  final TrackModel track;
  final int maxDepth;
  final bool hasStartBorder;

  const _Header({
    required this.track,
    required this.maxDepth,
    required this.hasStartBorder,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    Iterable<Color> getColors() sync* {
      var trackPtr = project.tracks[track.parentTrackId];

      while (trackPtr != null) {
        yield trackPtr.color.colorShifter.baseColor;
        trackPtr = project.tracks[trackPtr.parentTrackId];
      }
    }

    final colors = getColors().toList().reversed;

    final colorBars = colors.map((color) {
      return [
        Container(height: _groupHeaderAddonHeight, color: color),
        Container(height: borderWidth, color: AnthemTheme.panel.border),
      ];
    }).flattened;

    return SizedBox(
      height:
          _baseHeaderHeight +
          (_groupHeaderAddonHeight + borderWidth) * maxDepth,
      child: Column(
        children: [
          ...colorBars,
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: track.color.colorShifter.baseColor,
                border: Border(
                  left: hasStartBorder
                      ? .new(color: AnthemTheme.panel.border, width: 2)
                      : .none,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 4.0,
                    right: 4.0,

                    // This vertically offsets from center, but the text doesn't
                    // look right without it
                    bottom: 4.0,
                  ),
                  child: Text(
                    track.name,
                    style: .new(
                      fontSize: 12,
                      overflow: .ellipsis,
                      color: const Color(0xBBFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterSection extends StatelessObserverWidget {
  final TrackModel track;

  const _MeterSection({required this.track});

  @override
  Widget build(BuildContext context) {
    final gainPort = track.gainNode?.getPortById(GainProcessorModel.gainPortId);

    return Padding(
      padding: .all(4),
      child: Column(
        children: [
          Container(
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: AnthemTheme.panel.border, width: 1),
              color: AnthemTheme.panel.backgroundDark,
              borderRadius: .vertical(top: .circular(4)),
            ),
          ),
          SizedBox(height: 1),
          Container(
            height: 154,
            decoration: BoxDecoration(
              border: Border.all(color: AnthemTheme.panel.border, width: 1),
              color: AnthemTheme.panel.backgroundDark,
              borderRadius: .vertical(bottom: .circular(4)),
            ),
            padding: .all(3),
            child: Row(
              crossAxisAlignment: .stretch,
              spacing: 2.0,
              children: [
                Expanded(child: MeterScale()),
                SizedBox(width: 11, child: _TrackDbMeter(track: track)),
                Slider(
                  value: gainPort?.parameterValue ?? 0.75,
                  width: 26,
                  axis: .vertical,
                  noBackground: true,
                  min: 0,
                  max: 1,
                  stickyPoints: [0.75],
                  hint: (value) =>
                      'Track gain: ${gainParameterValueToString(value)}',
                  onValueChanged: (value) {
                    if (gainPort == null) {
                      return;
                    }

                    gainPort.parameterValue = value;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackDbMeter extends StatelessWidget {
  final TrackModel track;

  const _TrackDbMeter({required this.track});

  @override
  Widget build(BuildContext context) {
    return MultiVisualizationBuilder.double(
      configs: track.dbMeterVisualizationIds
          .map(VisualizationSubscriptionConfig.max)
          .toList(growable: false),
      builder: (context, values, engineTimes) {
        final hasStereoValues = values.length >= 2;
        final hasFullTimestampSet =
            engineTimes.length >= 2 &&
            engineTimes[0] != null &&
            engineTimes[1] != null;

        if (!hasStereoValues || !hasFullTimestampSet) {
          return const Meter(
            db: (left: -180.0, right: -180.0),
            timestamp: Duration.zero,
          );
        }

        final leftTime = engineTimes[0]!;
        final rightTime = engineTimes[1]!;

        return Meter(
          db: (left: values[0], right: values[1]),
          timestamp: leftTime.compareTo(rightTime) >= 0 ? leftTime : rightTime,
        );
      },
    );
  }
}
