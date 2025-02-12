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

import 'package:anthem/widgets/basic/controls/digit_control.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:flutter/widgets.dart';

class WidgetTestArea extends StatefulWidget {
  const WidgetTestArea({super.key});

  @override
  State<WidgetTestArea> createState() => _WidgetTestAreaState();
}

class _WidgetTestAreaState extends State<WidgetTestArea> {
  double digitControlValue = 128;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 3,
        children: [
          DigitControl(
            size: DigitDisplaySize.large,
            value: digitControlValue,
            minCharacterCount: 6,
            onChanged: (v) => setState(() => digitControlValue = v),
          ),
          DigitControl(
            width: 80,
            size: DigitDisplaySize.large,
            value: digitControlValue,
            onChanged: (v) => setState(() => digitControlValue = v),
          ),
          DigitControl(
            width: 80,
            value: digitControlValue,
            onChanged: (v) => setState(() => digitControlValue = v),
          ),
          DigitControl(
            width: 80,
            value: digitControlValue,
            decimalPlaces: 3,
            onChanged: (v) => setState(() => digitControlValue = v),
          ),
          DigitControl(
            width: 80,
            value: digitControlValue,
            decimalPlaces: 0,
            onChanged: (v) => setState(() => digitControlValue = v),
          ),
          TextBox(
            width: 100,
            height: 26,
          ),
        ],
      ),
    );
  }
}
