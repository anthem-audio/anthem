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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:flutter/widgets.dart';

class NoteWidget extends StatefulWidget {
  const NoteWidget({
    Key? key,
    required this.note,
    required this.isSelected,
    required this.isPressed,
    required this.notesUnderCursor,
  }) : super(key: key);

  final NoteModel note;
  final bool isSelected;
  final bool isPressed;

  /// See [PianoRollEventListener] for details on what this is for.
  final List<ID> notesUnderCursor;

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  bool isHovered = false;

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

    if (isHovered) {
      saturation -= 0.06;
      lightness += 0.04;
    }

    final color = HSLColor.fromAHSL(1, 166, saturation, lightness).toColor();

    return Listener(
      onPointerDown: (e) {
        widget.notesUnderCursor.add(widget.note.id);
      },
      onPointerMove: (e) {
        widget.notesUnderCursor.add(widget.note.id);
      },
      onPointerUp: (e) {
        widget.notesUnderCursor.add(widget.note.id);
      },
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
    );
  }
}
