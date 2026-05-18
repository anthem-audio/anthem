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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_headers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phantom automation lane rows can be resized', (tester) async {
    final fixture = _TrackHeadersTestFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });

    final phantomLane = fixture.showPhantomAutomationLane();
    final phantomRowId = phantomLane.id;

    await fixture.pump(tester);

    final rowIndex = fixture.arrangerViewModel.trackPositionCalculator
        .rowIdToIndex(phantomRowId);
    final initialHeight = fixture.arrangerViewModel.trackPositionCalculator
        .getTrackHeight(rowIndex);

    final handleFinder = find.byKey(Key('phantom-$phantomRowId-handle'));
    expect(handleFinder, findsOneWidget);
    expect(fixture.arrangerViewModel.rowHeightModifier(phantomRowId), 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final handleCenter = tester.getCenter(handleFinder);
    await mouse.down(handleCenter);
    await tester.pump();
    await mouse.moveTo(handleCenter + const Offset(0, 24));
    await tester.pump();
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      fixture.arrangerViewModel.rowHeightModifier(phantomRowId),
      greaterThan(1),
    );
    expect(
      fixture.arrangerViewModel.trackPositionCalculator.getTrackHeight(
        rowIndex,
      ),
      greaterThan(initialHeight),
    );
  });
}

class _TrackHeadersTestFixture {
  static const viewSize = Size(190, 260);

  final ProjectModel project;

  _TrackHeadersTestFixture._(this.project);

  factory _TrackHeadersTestFixture.create() {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);
    return _TrackHeadersTestFixture._(project);
  }

  ServiceRegistry get serviceRegistry => ServiceRegistry.forProject(project.id);

  ArrangerViewModel get arrangerViewModel => serviceRegistry.arrangerViewModel;

  Id get trackId => project.trackOrder.first;

  PhantomAutomationLaneInfo showPhantomAutomationLane() {
    arrangerViewModel.automationExpandedByTrackId[trackId] = true;
    final phantomLane = arrangerViewModel.phantomAutomationLaneForTrack(
      trackId,
    )!;
    arrangerViewModel.refreshTrackLayout(viewSize.height);
    return phantomLane;
  }

  Future<void> pump(WidgetTester tester) async {
    arrangerViewModel.refreshTrackLayout(viewSize.height);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProjectModel>.value(value: project),
          Provider<ArrangerViewModel>.value(value: arrangerViewModel),
          Provider<ScreenOverlayController>(
            create: (_) =>
                ScreenOverlayController(viewModel: ScreenOverlayViewModel()),
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: viewSize.width,
              height: viewSize.height,
              child: const TrackHeaders(verticalScrollPosition: 0),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  void dispose() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  }
}
