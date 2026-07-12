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

import 'package:anthem/demos/scheduler_workbench/canvas/graph_painter.dart';
import 'package:anthem/demos/scheduler_workbench/canvas/node_title_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('renderNodeTitleImage', () {
    test('renders node titles at the requested device pixel ratio', () async {
      final image = await renderNodeTitleImage(
        title: 'Node',
        devicePixelRatio: 2,
        maxTextWidth: GraphPainter.nodeTitleMaxWidth,
        maxTextHeight: GraphPainter.nodeTitleMaxHeight,
      );

      try {
        expect(image.width, ((GraphPainter.nodeTitleMaxWidth + 8) * 2).ceil());
        expect(
          image.height,
          ((GraphPainter.nodeTitleMaxHeight + 6) * 2).ceil(),
        );
      } finally {
        image.dispose();
      }
    });
  });
}
