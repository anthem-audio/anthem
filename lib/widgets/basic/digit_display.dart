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
  static double calculateHeight(DigitDisplaySize size) {
    return switch (size) {
      DigitDisplaySize.normal => 20,
      DigitDisplaySize.large => 24,
    };
  }

  static double calculateFontSize(DigitDisplaySize size) {
    return switch (size) {
      DigitDisplaySize.normal => 11,
      DigitDisplaySize.large => 14,
    };
  }

  final int? width;
  final DigitDisplaySize size;
  final bool monospace;

  final String text;

  final Widget? overlay;

  const DigitDisplay({
    super.key,
    this.width,
    this.size = DigitDisplaySize.normal,
    required this.text,
    this.monospace = false,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: calculateHeight(size),
      width: width?.toDouble(),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.separator),
        borderRadius: BorderRadius.circular(3),
        color: Theme.control.background,
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.only(
              left: 8,
              right: 8,
              // We need to add 1 to the top padding to make the text align,
              // since it's trying to vertically center it as if there are
              // letters that go below the baseline. We only want to display
              // numbers.
              top: 1,
            ),

            // If we set the alignnment when the width is not defined, then it
            // tries to take all the available space, so we only set it when
            // the width is defined.
            alignment: width != null ? Alignment.centerRight : null,
            child: Text(
              text,
              style: TextStyle(
                fontFamily: monospace ? 'RobotoMono' : null,
                fontSize: calculateFontSize(size),
                fontWeight: FontWeight.w700,
                color: Theme.primary.main,
              ),
            ),
          ),
          if (overlay != null)
            Positioned.fill(
              child: overlay!,
            ),
        ],
      ),
    );
  }
}
