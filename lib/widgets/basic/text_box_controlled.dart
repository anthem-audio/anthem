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

import 'package:anthem/widgets/basic/text_box.dart';
import 'package:flutter/widgets.dart';

class ControlledTextBox extends StatefulWidget {
  final String text;
  final void Function(String newText)? onChange;

  const ControlledTextBox({
    Key? key,
    required this.text,
    this.onChange,
  }) : super(key: key);

  @override
  State<ControlledTextBox> createState() => ControlledTextBoxState();
}

class ControlledTextBoxState extends State<ControlledTextBox> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  bool hasFocus = false;

  @override
  void initState() {
    focusNode.addListener(() {
      if (!hasFocus && focusNode.hasFocus) {
        hasFocus = true;
      } else if (hasFocus &&
          !focusNode.hasFocus &&
          widget.text != controller.text) {
        widget.onChange?.call(controller.text);
      }
    });

    controller.text = widget.text;

    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ControlledTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.text = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return TextBox(
      controller: controller,
      focusNode: focusNode,
    );
  }
}
