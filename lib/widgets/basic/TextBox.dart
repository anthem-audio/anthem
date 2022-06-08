/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

class TextBox extends StatefulWidget {
  const TextBox({Key? key}) : super(key: key);

  @override
  State<TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<TextBox> {
  TextEditingController? controller;
  FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    controller ??= TextEditingController();
    focusNode ??= FocusNode();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.panel.border),
        borderRadius: BorderRadius.circular(4),
        color: Theme.panel.accentDark,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: EditableText(
            backgroundCursorColor:
                const Color(0xFFFF0000), // I have no idea what this is
            selectionColor: Theme.primary.subtleBorder,
            controller: controller!,
            cursorColor: Theme.text.main,
            focusNode: focusNode!,
            style: TextStyle(
              color: Theme.text.main,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
