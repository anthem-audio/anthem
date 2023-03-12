/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_controller.dart';
import 'package:flutter/widgets.dart';

import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import '../shared/helpers/types.dart';
import 'piano_roll_notifications.dart';

class PianoRollNotificationHandler extends StatelessWidget {
  const PianoRollNotificationHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final controller = Provider.of<PianoRollController>(context);

    return NotificationListener<PianoRollNotification>(
      onNotification: (notification) {
        final timeView = Provider.of<TimeView>(context, listen: false);
        final patternID = project.song.activePatternID;

        /*
            This feels excessive, as it recalculates snap for each
            notification. I'm not sure whether this is actually slower than
            memoizing in the average case, so it's probably best to profile
            before going down that route.
          */

        final pattern = project.song.patterns[patternID];

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: notification.pianoRollSize.width,
          // TODO: this constant was copied from the minor division changes
          // getter in piano_roll_grid.dart
          minPixelsPerSection: 8,
          snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
          defaultTimeSignature: pattern?.defaultTimeSignature,
          timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: timeView.start,
          timeViewEnd: timeView.end,
        );

        if (notification is PianoRollPointerDownNotification) {
          final notificationTime = notification.time.floor();
          if (notificationTime < 0) return true;

          int targetTime = getSnappedTime(
            rawTime: notificationTime,
            divisionChanges: divisionChanges,
          );

          // projectCubit.journalStartEntry();
          controller.addNote(
            key: notification.note.floor(),
            velocity: 128,
            length: 96,
            offset: targetTime,
          );
          // controller.addNote(
          //       instrumentID: instrumentID,
          //       key: notification.note.floor() - 1,
          //       velocity: 128,
          //       length: 96,
          //       offset: targetTime,
          //     );
          // projectCubit.journalCommitEntry();
          return true;
        } else if (notification is PianoRollPointerMoveNotification) {
          // print(
          //     "pointer move: ${notification.note}, time: ${notification.time}");
          return true;
        } else if (notification is PianoRollPointerUpNotification) {
          // print(
          //     "pointer up: ${notification.note}, time: ${notification.time}");
          return true;
        } else if (notification
            is PianoRollTimeSignatureChangeAddNotification) {
          int targetTime = getSnappedTime(
            rawTime: notification.time.floor(),
            divisionChanges: divisionChanges,
            roundUp: true,
          );

          controller.addTimeSignatureChange(
              TimeSignatureModel(3, 4), targetTime);

          return true;
        }
        return false;
      },
      child: child,
    );
  }
}
