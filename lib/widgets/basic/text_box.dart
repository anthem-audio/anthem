/*
  Copyright (C) 2022 - 2025 Joshua Wade

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

import 'package:anthem/theme.dart' as anthem_theme;
import 'package:flutter/material.dart';

class TextBox extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;

  final double? width;
  final double? height;

  const TextBox({
    super.key,
    this.controller,
    this.focusNode,
    this.width,
    this.height,
  });

  @override
  State<TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<TextBox> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: anthem_theme.Theme.panel.border),
        borderRadius: BorderRadius.circular(4),
        color: anthem_theme.Theme.panel.accentDark,
      ),
      padding: const EdgeInsets.only(left: 8, right: 8),
      height: widget.height,
      width: widget.width,
      child: Center(
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: InputDecoration(border: InputBorder.none, isDense: true),
          maxLines: 1,
          cursorColor: anthem_theme.Theme.text.main,
          style: TextStyle(color: anthem_theme.Theme.text.main, fontSize: 11),
        ),
      ),
    );
  }
}
