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

import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:flutter/widgets.dart';

export 'package:anthem/widgets/basic/digit_display.dart' show DigitDisplaySize;

class DigitControl extends StatefulWidget {
  final DigitDisplaySize size;
  final int? width;

  const DigitControl({
    super.key,
    this.size = DigitDisplaySize.normal,
    this.width,
  });

  @override
  State<DigitControl> createState() => _DigitControlState();
}

class _DigitControlState extends State<DigitControl> {
  @override
  Widget build(BuildContext context) {
    return DigitDisplay(
      text: '128.00',
      width: widget.width,
      size: widget.size,
    );
  }
}
