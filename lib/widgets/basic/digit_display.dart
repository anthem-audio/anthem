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

enum DigitDisplaySize { normal, large }

class DigitDisplay extends StatelessWidget {
  final int? width;
  final DigitDisplaySize size;

  final String text;

  const DigitDisplay({
    super.key,
    this.width,
    this.size = DigitDisplaySize.normal,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: switch (size) {
        DigitDisplaySize.normal => 20,
        DigitDisplaySize.large => 24,
      },
      width: width?.toDouble(),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.separator),
        borderRadius: BorderRadius.circular(3),
        color: Theme.control.background,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: switch (size) {
                  DigitDisplaySize.normal => 11,
                  DigitDisplaySize.large => 14,
                },
                fontWeight: FontWeight.w700,
                color: Theme.primary.main,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
