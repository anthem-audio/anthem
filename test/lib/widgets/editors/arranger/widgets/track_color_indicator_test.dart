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

import 'package:anthem/widgets/editors/arranger/widgets/arranger_diagonal_pattern.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_color_indicator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only descendant-spanning indicators render the pattern', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: const [
            SizedBox(
              width: 100,
              height: 80,
              child: TrackColorIndicator(
                color: Color(0xFF123456),
                trackHeight: 40,
                spansDescendants: true,
              ),
            ),
            SizedBox(
              width: 100,
              height: 40,
              child: TrackColorIndicator(
                color: Color(0xFF123456),
                trackHeight: 40,
                spansDescendants: false,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ArrangerDiagonalPattern), findsOneWidget);
  });
}
