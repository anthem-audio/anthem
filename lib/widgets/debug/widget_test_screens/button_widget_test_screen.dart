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
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_group.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:flutter/widgets.dart';

class ButtonWidgetTestScreen extends StatefulWidget {
  const ButtonWidgetTestScreen({super.key});

  @override
  State<ButtonWidgetTestScreen> createState() => _ButtonWidgetTestScreenState();
}

class _ButtonWidgetTestScreenState extends State<ButtonWidgetTestScreen> {
  int primaryPressCount = 0;
  int rightClickCount = 0;
  bool toggleState = false;
  bool groupA = false;
  bool groupB = false;
  bool groupC = false;
  bool groupTop = false;
  bool groupMiddle = false;
  bool groupBottom = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 150,
              height: 30,
              child: Button(
                text: 'Main',
                onPress: () {
                  setState(() {
                    primaryPressCount += 1;
                  });
                },
                onRightClick: () {
                  setState(() {
                    rightClickCount += 1;
                  });
                },
                hint: [HintSection('click', 'Increments primary press count')],
              ),
            ),
            SizedBox(
              width: 150,
              height: 30,
              child: Button(
                variant: ButtonVariant.label,
                text: 'Label',
                onPress: () {
                  setState(() {
                    primaryPressCount += 1;
                  });
                },
              ),
            ),
            SizedBox(
              width: 150,
              height: 30,
              child: Button(
                variant: ButtonVariant.ghost,
                text: 'Ghost',
                onPress: () {
                  setState(() {
                    primaryPressCount += 1;
                  });
                },
              ),
            ),
            SizedBox(
              width: 150,
              height: 30,
              child: Button(
                text: 'Menu indicator',
                showMenuIndicator: true,
                onPress: () {
                  setState(() {
                    primaryPressCount += 1;
                  });
                },
              ),
            ),
            SizedBox(
              width: 150,
              height: 30,
              child: Button(
                text: toggleState ? 'Toggle: ON' : 'Toggle: OFF',
                toggleState: toggleState,
                onPress: () {
                  setState(() {
                    toggleState = !toggleState;
                  });
                },
              ),
            ),
          ],
        ),
        Text(
          'Primary clicks: $primaryPressCount',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
        Text(
          'Right clicks: $rightClickCount',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
        Text(
          'ButtonGroup (horizontal)',
          style: TextStyle(
            color: AnthemTheme.text.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          height: 26,
          child: ButtonGroup(
            children: [
              Button(
                width: 70,
                text: 'One',
                toggleState: groupA,
                onPress: () {
                  setState(() {
                    groupA = !groupA;
                  });
                },
              ),
              Button(
                width: 70,
                text: 'Two',
                toggleState: groupB,
                onPress: () {
                  setState(() {
                    groupB = !groupB;
                  });
                },
              ),
              Button(
                width: 70,
                text: 'Three',
                toggleState: groupC,
                onPress: () {
                  setState(() {
                    groupC = !groupC;
                  });
                },
              ),
            ],
          ),
        ),
        Text(
          'ButtonGroup (vertical)',
          style: TextStyle(
            color: AnthemTheme.text.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          width: 120,
          child: ButtonGroup(
            axis: Axis.vertical,
            children: [
              Button(
                height: 24,
                text: 'Top',
                toggleState: groupTop,
                onPress: () {
                  setState(() {
                    groupTop = !groupTop;
                  });
                },
              ),
              Button(
                height: 24,
                text: 'Middle',
                toggleState: groupMiddle,
                onPress: () {
                  setState(() {
                    groupMiddle = !groupMiddle;
                  });
                },
              ),
              Button(
                height: 24,
                text: 'Bottom',
                toggleState: groupBottom,
                onPress: () {
                  setState(() {
                    groupBottom = !groupBottom;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
