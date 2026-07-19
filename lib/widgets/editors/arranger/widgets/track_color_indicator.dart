/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

import 'arranger_diagonal_pattern.dart';

const _extendedIndicatorColorWidth = 8.0;

/// Paints the color assigned to a row or group of rows.
class TrackColorIndicator extends StatelessWidget {
  final Color color;
  final double trackHeight;
  final bool spansDescendants;

  const TrackColorIndicator({
    super.key,
    required this.color,
    required this.trackHeight,
    required this.spansDescendants,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: AnthemTheme.panel.border, width: 1),
        ),
      ),
      child: spansDescendants
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: trackHeight),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AnthemTheme.panel.border,
                                width: 1,
                              ),
                              right: BorderSide(
                                color: AnthemTheme.panel.border,
                                width: 1,
                              ),
                            ),
                          ),
                          child: const ArrangerDiagonalPattern(),
                        ),
                      ),
                      const SizedBox(width: _extendedIndicatorColorWidth),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
