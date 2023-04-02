/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/clip/clip_notes.dart';
import 'package:anthem/widgets/editors/arranger/event_listener.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class Clip extends StatelessWidget {
  final ID? clipID;
  final ID? patternID;
  final ID? arrangementID;
  final double ticksPerPixel;
  final bool selected;
  final ClipWidgetEventData? eventData;

  /// Creates a Clip widget tied to a ClipModel
  const Clip({
    Key? key,
    required this.clipID,
    required this.arrangementID,
    required this.ticksPerPixel,
    this.selected = false,
    this.eventData,
  })  : patternID = null,
        super(key: key);

  /// Creates a Clip widget tied to a PatternModel
  const Clip.fromPattern({
    Key? key,
    required this.patternID,
    required this.ticksPerPixel,
  })  : selected = false,
        clipID = null,
        arrangementID = null,
        eventData = null,
        super(key: key);

  void _onPointerEvent(PointerEvent e) {
    eventData?.clipsUnderCursor.add(clipID!);
  }

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final clipModel =
        projectModel.song.arrangements[arrangementID]?.clips[clipID];
    final patternModel =
        projectModel.song.patterns[clipModel?.patternID ?? patternID!]!;

    return Listener(
      onPointerDown: _onPointerEvent,
      onPointerMove: _onPointerEvent,
      onPointerUp: _onPointerEvent,
      onPointerCancel: _onPointerEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Observer(builder: (context) {
            return Container(
              height: 15,
              decoration: BoxDecoration(
                color: getBaseColor(patternModel.color, selected),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                patternModel.name,
                style: TextStyle(
                  color: getTextColor(patternModel.color, selected),
                  fontSize: 10,
                ),
              ),
            );
          }),
          Observer(builder: (context) {
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: getBaseColor(patternModel.color, selected)
                      .withAlpha(0x66),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ClipNotes(
                    color: getContentColor(patternModel.color, selected),
                    timeViewStart: 0,
                    ticksPerPixel: ticksPerPixel,
                    pattern: patternModel,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

Color getBaseColor(AnthemColor color, bool selected) {
  final hue = selected ? 166.0 : color.hue;
  final saturation =
      selected ? 0.6 : (0.28 * color.saturationMultiplier).clamp(0.0, 1.0);
  final lightness =
      selected ? 0.31 : (0.49 * color.lightnessMultiplier).clamp(0.0, 0.92);

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}

Color getTextColor(AnthemColor color, bool selected) {
  final hue = selected ? 166.0 : color.hue;
  final saturation =
      selected ? 1.0 : (1 * color.saturationMultiplier).clamp(0.0, 1.0);
  final lightness =
      selected ? 0.92 : (0.92 * color.lightnessMultiplier).clamp(0.0, 0.92);

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}

Color getContentColor(AnthemColor color, bool selected) {
  final hue = selected ? 166.0 : color.hue;
  final saturation =
      selected ? 0.7 : (0.7 * color.saturationMultiplier).clamp(0.0, 1.0);
  final lightness =
      selected ? 0.78 : (0.78 * color.lightnessMultiplier).clamp(0.0, 0.92);

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}
