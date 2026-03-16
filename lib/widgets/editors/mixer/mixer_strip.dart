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
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/theme.dart';
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
      ),
      child: Column(
        children: [
          _Header(
            track: track,
            maxDepth: widget.maxTrackDepth,
            hasStartBorder: widget.hasStartBorder,
          ),
          _spacer(),
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
