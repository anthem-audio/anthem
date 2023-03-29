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

import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_event_listener.dart';
import 'package:flutter/widgets.dart';

const noteResizeHandleWidth = 10.0;
const noteResizeHandleOvershoot =
    3.0; // How far the resize handle extends past the end of the note

class NoteWidget extends StatefulWidget {
  const NoteWidget({
    Key? key,
    required this.note,
    required this.isSelected,
    required this.isPressed,
    required this.eventData,
  }) : super(key: key);

  final NoteModel note;
  final bool isSelected;
  final bool isPressed;

  /// See [PianoRollEventListener] for details on what this is for.
  final NoteWidgetEventData eventData;

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  bool isHovered = false;

  void _onPointerEvent(PointerEvent e) {
    widget.eventData.notesUnderCursor.add(widget.note.id);
  }

  @override
  Widget build(BuildContext context) {
    var saturation = widget.isPressed
        ? 0.6
        : widget.isSelected
            ? 0.37
            : 0.46;

    var lightness = widget.isPressed
        ? 0.22
        : widget.isSelected
            ? 0.37
            : 0.31;

    if (isHovered && !widget.isPressed) {
      saturation -= 0.06;
      lightness += 0.04;
    }

    final color = HSLColor.fromAHSL(1, 166, saturation, lightness).toColor();

    return Listener(
      onPointerDown: _onPointerEvent,
      onPointerMove: _onPointerEvent,
      onPointerUp: _onPointerEvent,
      onPointerCancel: _onPointerEvent,
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
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              right: noteResizeHandleOvershoot,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.all(Radius.circular(1)),
                  border: Border.all(
                    color: widget.isSelected
                        ? const HSLColor.fromAHSL(1, 166, 0.35, 0.45).toColor()
                        : const Color(0x00000000),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: SizedBox(
                width: noteResizeHandleWidth,
                child: Listener(
                  onPointerDown: (e) {
                    widget.eventData.isResizeEvent = true;
                  },
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
