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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/radio_button.dart';
import 'package:flutter/widgets.dart';

enum _RadioButtonDemoOption { first, second, third }

class RadioButtonWidgetTestScreen extends StatefulWidget {
  const RadioButtonWidgetTestScreen({super.key});

  @override
  State<RadioButtonWidgetTestScreen> createState() =>
      _RadioButtonWidgetTestScreenState();
}

class _RadioButtonWidgetTestScreenState
    extends State<RadioButtonWidgetTestScreen> {
  _RadioButtonDemoOption selectedOption = _RadioButtonDemoOption.first;

  @override
  Widget build(BuildContext context) {
    Widget buildOption({
      required _RadioButtonDemoOption option,
      required String label,
    }) {
      return AnthemRadioButton(
        selected: selectedOption == option,
        label: label,
        onSelected: () {
          setState(() {
            selectedOption = option;
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Radio buttons',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            AnthemRadioButton(
              selected: selectedOption == _RadioButtonDemoOption.first,
              onSelected: () {
                setState(() {
                  selectedOption = _RadioButtonDemoOption.first;
                });
              },
            ),
            buildOption(option: _RadioButtonDemoOption.first, label: 'First'),
            buildOption(option: _RadioButtonDemoOption.second, label: 'Second'),
            buildOption(option: _RadioButtonDemoOption.third, label: 'Third'),
            const AnthemRadioButton(selected: true, label: 'Read-only'),
          ],
        ),
      ],
    );
  }
}
