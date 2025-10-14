/*
  Copyright (C) 2025 Joshua Wade

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

abstract class DialogControllerImpl {
  void showDialog(Widget content, {String? title, List<DialogButton>? buttons});
  void closeDialog();
}

class DialogController {
  DialogControllerImpl? _impl;

  void initialize(DialogControllerImpl impl) {
    _impl = impl;
  }

  void dispose() {
    _impl = null;
  }

  void showDialog({
    String? title,
    required Widget content,
    List<DialogButton>? buttons,
  }) {
    _impl?.showDialog(content, title: title, buttons: buttons);
  }

  void showTextDialog({
    String? title,
    String? text,
    TextSpan? textSpan,
    List<DialogButton>? buttons,
  }) {
    if (text == null && textSpan == null) {
      throw ArgumentError('Either text or textSpan must be provided.');
    }

    const maxWidth = 400.0;

    if (textSpan != null) {
      _impl?.showDialog(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: RichText(text: textSpan),
        ),
        title: title,
        buttons: buttons,
      );
      return;
    }

    _impl?.showDialog(
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Text(
          text!,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ),
      title: title,
      buttons: buttons,
    );
  }

  void closeDialog() {
    _impl?.closeDialog();
  }
}

class DialogButton {
  final String text;
  final void Function()? onPress;

  DialogButton({required this.text, this.onPress});

  DialogButton.ok({this.onPress}) : text = 'OK';
  DialogButton.cancel({this.onPress}) : text = 'Cancel';
}
