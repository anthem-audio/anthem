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

import 'package:anthem/model/project.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/widgets/editors/arranger/widgets/arranger_diagonal_pattern.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_color_indicator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('only descendant-spanning indicators render the pattern', (
    tester,
  ) async {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);
    addTearDown(() {
      ServiceRegistry.removeProject(project.id);
      project.dispose();
    });
    final trackId = project.trackOrder.first;

    await tester.pumpWidget(
      Provider<ProjectModel>.value(
        value: project,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SizedBox(
                width: 100,
                height: 80,
                child: TrackColorIndicator(
                  trackId: trackId,
                  trackHeight: 40,
                  spansDescendants: true,
                ),
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: TrackColorIndicator(
                  trackId: trackId,
                  trackHeight: 40,
                  spansDescendants: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(ArrangerDiagonalPattern), findsOneWidget);
  });
}
