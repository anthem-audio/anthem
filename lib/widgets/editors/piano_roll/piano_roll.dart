/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'dart:math';

import 'package:anthem/model/note.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_cubit.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_event_listener.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_notification_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:provider/provider.dart';

import '../../../model/store.dart';
import '../../../theme.dart';
import '../../basic/panel.dart';
import '../shared/helpers/time_helpers.dart';
import '../shared/helpers/types.dart';
import '../shared/timeline_cubit.dart';
import 'helpers.dart';
import 'piano_roll_grid.dart';
import '../shared/timeline.dart';
import 'piano_control.dart';

const double minKeyHeight = 6;
const double maxKeyHeight = 40;

class PianoRoll extends StatefulWidget {
  const PianoRoll({
    Key? key,
  }) : super(key: key);

  @override
  _PianoRollState createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PianoRollCubit, PianoRollState>(
        builder: (context, state) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TimeView(0, 3072)),
        ],
        child: PianoRollNotificationHandler(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.panel.main,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PianoRollHeader(),
                  const SizedBox(height: 4),
                  const Expanded(
                    child: _PianoRollContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _PianoRollHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 26,
    );
  }
}

class _PianoRollContent extends StatefulWidget {
  const _PianoRollContent({
    Key? key,
  }) : super(key: key);

  @override
  State<_PianoRollContent> createState() => _PianoRollContentState();
}

class _PianoRollContentState extends State<_PianoRollContent> {
  double footerHeight = 61;
  double pianoControlWidth = 69;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PianoRollCubit, PianoRollState>(
        builder: (context, state) {
      final cubit = BlocProvider.of<PianoRollCubit>(context);

      final project = Store.instance.projects[state.projectID];
      final pattern = project?.song.patterns[state.patternID];

      final timeView = context.watch<TimeView>();

      final timelineHeight =
          (pattern?.timeSignatureChanges.length ?? 0) > 0 ? 42.0 : 21.0;

      final notes = state.notes;

      return Panel(
        orientation: PanelOrientation.bottom,
        panelStartSize: 89,
        separatorSize: 6,
        child: Column(
          children: [
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 4),
                  VerticalScaleControl(
                    min: minKeyHeight,
                    max: maxKeyHeight,
                    value: state.keyHeight,
                    onChange: (height) {
                      cubit.setKeyHeight(height);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.panel.border),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                        child: Column(
                          children: [
                            // Timeline
                            SizedBox(
                              height: timelineHeight,
                              child: Row(
                                children: [
                                  SizedBox(width: pianoControlWidth),
                                  Container(
                                      color: Theme.panel.border, width: 1),
                                  Expanded(
                                    child: BlocProvider<TimelineCubit>(
                                      create: (context) => TimelineCubit(
                                        projectID: state.projectID,
                                        timelineType:
                                            TimelineType.patternTimeline,
                                      ),
                                      child: const Timeline(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(color: Theme.panel.border, height: 1),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Piano control
                                  SizedBox(
                                    width: pianoControlWidth,
                                    child: PianoControl(
                                      keyValueAtTop: state.keyValueAtTop,
                                      keyHeight: state.keyHeight,
                                      setKeyValueAtTop: (value) {
                                        setState(() {
                                          cubit.setKeyValueAtTop(value);
                                        });
                                      },
                                    ),
                                  ),
                                  Container(
                                      color: Theme.panel.border, width: 1),
                                  // Main piano roll render area
                                  Expanded(
                                    child: PianoRollEventListener(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          PianoRollGrid(
                                            keyHeight: state.keyHeight,
                                            keyValueAtTop:
                                                state.keyValueAtTop,
                                          ),
                                          ClipRect(
                                            child: CustomMultiChildLayout(
                                              children: notes
                                                  .map(
                                                    (note) => LayoutId(
                                                      id: note.id,
                                                      child: NoteWidget(
                                                          noteID: note.id),
                                                    ),
                                                  )
                                                  .toList(),
                                              delegate: NoteLayoutDelegate(
                                                notes: notes,
                                                keyHeight: state.keyHeight,
                                                keyValueAtTop:
                                                    state.keyValueAtTop,
                                                timeViewStart: timeView.start,
                                                timeViewEnd: timeView.end,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Vertical scrollbar
                  const SizedBox(width: 4),
                  Container(
                    width: 17,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.panel.border),
                      color: Theme.panel.accent,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        panelContent: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.panel.border),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
      );
    });
  }
}

class NoteLayoutDelegate extends MultiChildLayoutDelegate {
  NoteLayoutDelegate({
    required this.notes,
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  final List<NoteModel> notes;
  final double timeViewStart;
  final double timeViewEnd;
  final double keyValueAtTop;
  final double keyHeight;

  @override
  void performLayout(Size size) {
    for (var note in notes) {
      final y = keyValueToPixels(
              keyValue: note.key.toDouble(),
              keyValueAtTop: keyValueAtTop,
              keyHeight: keyHeight) -
          keyHeight +
          // this is why I want Dart support for Prettier
          1;
      final height = keyHeight.toDouble() - 1;
      final startX = timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: note.offset.toDouble()) +
          1;
      final width = timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: timeViewStart + note.length.toDouble()) -
          1;

      layoutChild(
        note.id,
        BoxConstraints(maxHeight: height, maxWidth: max(width, 0)),
      );
      positionChild(note.id, Offset(startX, y));
    }
  }

  @override
  bool shouldRelayout(covariant NoteLayoutDelegate oldDelegate) {
    if (oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.notes.length != notes.length ||
        oldDelegate.keyHeight != keyHeight ||
        oldDelegate.keyValueAtTop != keyValueAtTop) return true;
    for (var i = 0; i < notes.length; i++) {
      var oldNote = oldDelegate.notes[i];
      var newNote = notes[i];

      // No re-layout on velocity. I think this is okay?
      if (oldNote.key != newNote.key ||
          oldNote.length != newNote.length ||
          oldNote.offset != newNote.offset) {
        return true;
      }
    }
    return false;
  }
}

class NoteWidget extends StatefulWidget {
  const NoteWidget({Key? key, required this.noteID}) : super(key: key);

  final int noteID;

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // TODO: Send off notification on focus loss (?) or people will be very confused maybe
      onPointerDown: (e) {
        // NotePointerNotification(
        //   isRightClick: e.buttons == kSecondaryMouseButton,
        //   pressed: true,
        //   noteID: 1,
        // ).dispatch(context);
        // PianoRollNotification().dispatch(context);
      },
      // onPointerUp: (e) {
      //   NotePointerNotification(
      //     isRightClick: e.buttons == kSecondaryMouseButton,
      //     pressed: false,
      //     noteID: 1,
      //   ).dispatch(context);
      // },
      child: MouseRegion(
        onEnter: (e) {
          setState(() {
            isHovered = true;
          });
        },
        onExit: (e) {
          setState(() {
            isHovered = false;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(
                    1, 166, isHovered ? 0.4 : 0.46, isHovered ? 0.35 : 0.31)
                .toColor(),
            borderRadius: const BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
    );
  }
}
