/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:flutter/widgets.dart';

class DialogWidgetTestScreen extends StatefulWidget {
  const DialogWidgetTestScreen({super.key});

  @override
  State<DialogWidgetTestScreen> createState() => _DialogWidgetTestScreenState();
}

class _DialogWidgetTestScreenState extends State<DialogWidgetTestScreen> {
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_dialogShown) {
      return;
    }

    _dialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ServiceRegistry.dialogController.showMarkdownDialog(
        title: 'Markdown Dialog',
        markdown:
            '# Markdown title\n\n'
            'Paragraph spacing is compact while still separating blocks.\n\n'
            '**Strong text**, *emphasis*, [links](https://anthem-audio.org), '
            'and `inline code` all render inside the standard dialog shell.\n\n'
            '- First list item\n'
            '- Second list item',
        buttons: [DialogButton.ok()],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: DialogRenderer(
        child: Container(
          color: AnthemTheme.panel.backgroundDark,
          child: Center(
            child: Text(
              'Dialog renderer test surface',
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
