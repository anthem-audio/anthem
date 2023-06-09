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
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

const noteResizeHandleWidth = 10.0;

// How far the resize handle extends past the end of the note
const noteResizeHandleOvershoot = 2.0;

class NoteWidget extends StatefulObserverWidget {
  const NoteWidget({
    Key? key,
    required this.note,
    required this.isSelected,
    required this.isPressed,
  }) : super(key: key);

  final NoteModel note;
  final bool isSelected;
  final bool isPressed;

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);

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
    final textColor = HSLColor.fromAHSL(
      1,
      166,
      (saturation * 0.6).clamp(0, 1),
      (lightness * 2).clamp(0, 1),
    ).toColor();

    final textOverlay = viewModel.keyHeight > 25
        ? Center(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w400,
                    overflow: TextOverflow.ellipsis,
                  ),
                  keyToString(widget.note.key),
                ),
              ),
            ),
          )
        : null;

    return MouseRegion(
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
        child: textOverlay,
      ),
    );
  }
}
