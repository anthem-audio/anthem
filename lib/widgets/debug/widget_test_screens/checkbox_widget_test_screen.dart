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
import 'package:anthem/widgets/basic/checkbox.dart';
import 'package:flutter/widgets.dart';

class CheckboxWidgetTestScreen extends StatefulWidget {
  const CheckboxWidgetTestScreen({super.key});

  @override
  State<CheckboxWidgetTestScreen> createState() =>
      _CheckboxWidgetTestScreenState();
}

class _CheckboxWidgetTestScreenState extends State<CheckboxWidgetTestScreen> {
  bool unlabeledValue = true;
  bool labeledValue = true;
  bool uncheckedValue = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Checkboxes',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            AnthemCheckbox(
              value: unlabeledValue,
              onChanged: (value) {
                setState(() {
                  unlabeledValue = value;
                });
              },
            ),
            AnthemCheckbox(
              value: labeledValue,
              label: 'Enabled',
              onChanged: (value) {
                setState(() {
                  labeledValue = value;
                });
              },
            ),
            AnthemCheckbox(
              value: uncheckedValue,
              label: 'Unchecked',
              onChanged: (value) {
                setState(() {
                  uncheckedValue = value;
                });
              },
            ),
            const AnthemCheckbox(value: true, label: 'Read-only'),
          ],
        ),
      ],
    );
  }
}
