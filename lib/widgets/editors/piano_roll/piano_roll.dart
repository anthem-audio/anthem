/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:anthem/widgets/editors/piano_roll/piano_roll_cubit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:plugin/generated/rid_api.dart';

import 'package:provider/provider.dart';

import 'helpers.dart';
import 'piano_roll_grid.dart';
import 'piano_roll_notifications.dart';
import 'timeline.dart';
import 'piano_control.dart';

class PianoRoll extends StatefulWidget {
  final int ticksPerQuarter;
  final int? channelID;

  const PianoRoll({
    Key? key,
    required this.ticksPerQuarter,
    required this.channelID,
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
        child: Column(
          children: [
            _PianoRollHeader(),
            Expanded(
              child: _PianoRollContent(
                ticksPerQuarter: widget.ticksPerQuarter,
                channelID: widget.channelID,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PianoRollHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.12),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
      ),
      height: 42,
    );
  }
}

// TODO: use providers instead of punching everything through

class _PianoRollContent extends StatefulWidget {
  final int ticksPerQuarter;
  final int? channelID;

  _PianoRollContent({
    Key? key,
    required this.ticksPerQuarter,
    required this.channelID,
  }) : super(key: key);

  @override
  State<_PianoRollContent> createState() => _PianoRollContentState();
}

class _PianoRollContentState extends State<_PianoRollContent> {
  double footerHeight = (61);
  double pianoControlWidth = (103);
  double keyValueAtTop = (64);
  double keyHeight = (20);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PianoRollCubit, PianoRollState>(
        builder: (context, state) {
      final pattern = state.pattern;

      final timeView = context.watch<TimeView>();

      final timelineHeight =
          (pattern?.timeSignatureChanges ?? []).isNotEmpty ? 42.0 : 21.0;

      final pianoRollContentListenerKey = GlobalKey();

      handlePointerDown(PointerDownEvent e) {
        final context = pianoRollContentListenerKey.currentContext;
        if (context == null) return;

        final contentRenderBox = context.findRenderObject() as RenderBox;
        final pointerPos = contentRenderBox.globalToLocal(e.position);

        PianoRollPointerDownNotification(
          note: pixelsToKeyValue(
              keyHeight: keyHeight,
              keyValueAtTop: keyValueAtTop,
              pixelOffsetFromTop: pointerPos.dy),
          time: pixelsToTime(
              timeViewStart: timeView.start,
              timeViewEnd: timeView.end,
              viewPixelWidth: context.size?.width ?? 1,
              pixelOffsetFromLeft: pointerPos.dx),
          event: e,
          pianoRollSize: contentRenderBox.size,
        ).dispatch(context);
      }

      handlePointerMove(PointerMoveEvent e) {
        final context = pianoRollContentListenerKey.currentContext;
        if (context == null) return;

        final contentRenderBox = context.findRenderObject() as RenderBox;
        final pointerPos = contentRenderBox.globalToLocal(e.position);

        PianoRollPointerMoveNotification(
          note: pixelsToKeyValue(
              keyHeight: keyHeight,
              keyValueAtTop: keyValueAtTop,
              pixelOffsetFromTop: pointerPos.dy),
          time: pixelsToTime(
              timeViewStart: timeView.start,
              timeViewEnd: timeView.end,
              viewPixelWidth: context.size?.width ?? 1,
              pixelOffsetFromLeft: pointerPos.dx),
          event: e,
          pianoRollSize: contentRenderBox.size,
        ).dispatch(context);
      }

      handlePointerUp(PointerUpEvent e) {
        final context = pianoRollContentListenerKey.currentContext;
        if (context == null) return;

        final contentRenderBox = context.findRenderObject() as RenderBox;
        final pointerPos = contentRenderBox.globalToLocal(e.position);

        PianoRollPointerUpNotification(
          note: pixelsToKeyValue(
              keyHeight: keyHeight,
              keyValueAtTop: keyValueAtTop,
              pixelOffsetFromTop: pointerPos.dy),
          time: pixelsToTime(
              timeViewStart: timeView.start,
              timeViewEnd: timeView.end,
              viewPixelWidth: context.size?.width ?? 1,
              pixelOffsetFromLeft: pointerPos.dx),
          event: e,
          pianoRollSize: contentRenderBox.size,
        ).dispatch(context);
      }

      final notes = pattern == null ? <Note>[] : pattern.channelNotes[widget.channelID]?.notes;

      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Piano control
                SizedBox(
                  width: pianoControlWidth,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF).withOpacity(0.12),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(1),
                            bottomRight: Radius.circular(1),
                          ),
                        ),
                        height: timelineHeight + 1,
                      ),
                      const SizedBox(height: 1),
                      Expanded(
                        child: PianoControl(
                          keyValueAtTop: keyValueAtTop,
                          keyHeight: keyHeight,
                          setKeyValueAtTop: (value) {
                            setState(() {
                              keyValueAtTop = value;
                            });
                          },
                          setKeyHeight: (value) {
                            setState(() {
                              keyHeight = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 1),
                    ],
                  ),
                ),
                // Timeline and main piano roll render area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(1, 1, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: timelineHeight,
                          child: Timeline(
                            pattern: pattern,
                            ticksPerQuarter: widget.ticksPerQuarter,
                          ),
                        ),
                        Expanded(
                          child: Listener(
                            key: pianoRollContentListenerKey,
                            onPointerDown: handlePointerDown,
                            onPointerMove: handlePointerMove,
                            onPointerUp: handlePointerUp,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PianoRollGrid(
                                  keyHeight: keyHeight,
                                  keyValueAtTop: keyValueAtTop,
                                  ticksPerQuarter: widget.ticksPerQuarter,
                                ),
                                ClipRect(
                                  child: CustomMultiChildLayout(
                                    children: (notes ?? [])
                                        .map(
                                          (note) => LayoutId(
                                            id: note.id,
                                            child: NoteWidget(noteID: note.id),
                                          ),
                                        )
                                        .toList(),
                                    delegate: NoteLayoutDelegate(
                                      notes: notes ?? [],
                                      keyHeight: keyHeight,
                                      keyValueAtTop: keyValueAtTop,
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
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFFFFFF).withOpacity(0.12),
            height: footerHeight,
          ),
        ],
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

  final List<Note> notes;
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
            color: const Color(0xFF07D2D4).withOpacity(isHovered ? 0.5 : 0.33),
            borderRadius: const BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
    );
  }
}
