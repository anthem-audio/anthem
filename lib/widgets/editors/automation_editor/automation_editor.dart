/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AutomationEditor extends StatefulWidget {
  const AutomationEditor({super.key});

  @override
  State<AutomationEditor> createState() => AutomationEditorState();
}

class AutomationEditorState extends State<AutomationEditor> {
  AutomationEditorViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    viewModel ??= AutomationEditorViewModel();

    return Provider.value(
      value: viewModel!,
      child: const Background(
        type: BackgroundType.dark,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AutomationEditorHeader(),
              SizedBox(height: 4),
              Flexible(child: _AutomationEditorContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutomationEditorHeader extends StatelessWidget {
  const _AutomationEditorHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Button(
            icon: Icons.kebab,
            width: 26,
          ),
        ],
      ),
    );
  }
}

class _AutomationEditorContent extends StatefulWidget {
  const _AutomationEditorContent();

  @override
  State<_AutomationEditorContent> createState() =>
      _AutomationEditorContentState();
}

class _AutomationEditorContentState extends State<_AutomationEditorContent> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
