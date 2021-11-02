import 'package:anthem/widgets/editors/piano_roll/piano_roll_cubit.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:provider/provider.dart';

import 'piano_roll_notifications.dart';

import 'helpers.dart';

class PianoRollNotificationHandler extends StatelessWidget {
  const PianoRollNotificationHandler({Key? key, required this.child})
      : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PianoRollCubit, PianoRollState>(
        builder: (context, state) {
      return NotificationListener<PianoRollNotification>(
          onNotification: (notification) {
            final timeView = Provider.of<TimeView>(context, listen: false);
            final instrumentID =
                BlocProvider.of<ProjectCubit>(context).state.activeInstrumentID;

            /*
              This feels excessive, as it recalculates snap for each
              notification. I'm not sure whether this is actually slower than
              memoizing in the average case, so it's probably best to profile
              before going down that route.
            */

            final divisionChanges = getDivisionChanges(
              viewWidthInPixels: notification.pianoRollSize.width,
              // TODO: this constant was copied from the minor division changes
              // getter in piano_roll_grid.dart
              minPixelsPerSection: 8,
              snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
              defaultTimeSignature: state.pattern?.defaultTimeSignature,
              timeSignatureChanges: state.pattern?.timeSignatureChanges ?? [],
              ticksPerQuarter: state.ticksPerQuarter,
              timeViewStart: timeView.start,
              timeViewEnd: timeView.end,
            );

            if (notification is PianoRollPointerDownNotification) {
              final notificationTime = notification.time.floor();
              if (notificationTime < 0) return true;

              int targetTime = -1;

              // A binary search might be better here, but it would only matter
              // if there were a *lot* of time signature changes in the pattern
              for (var i = 0; i < divisionChanges.length; i++) {
                if (notificationTime >= 0 &&
                    i < divisionChanges.length - 1 &&
                    divisionChanges[i + 1].offset <= notificationTime) {
                  continue;
                }

                final divisionChange = divisionChanges[i];
                final snapSize = divisionChange.divisionSnapSize;
                targetTime = (notificationTime ~/ snapSize) * snapSize;
                break;
              }

              final pianoRollCubit = context.read<PianoRollCubit>();
              // final projectCubit = context.read<ProjectCubit>();

              // projectCubit.journalStartEntry();
              pianoRollCubit.addNote(
                    instrumentID: instrumentID,
                    key: notification.note.floor(),
                    velocity: 128,
                    length: 96,
                    offset: targetTime,
                  );
              // pianoRollCubit.addNote(
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
            }
            return false;
          },
          child: child);
    });
  }
}
