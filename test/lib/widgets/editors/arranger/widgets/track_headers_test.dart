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
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
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

    final rowIndex = fixture.arrangerViewModel.trackLayout.rowIdToIndex(
      phantomRowId,
    );
    final initialHeight = fixture.arrangerViewModel.trackLayout
        .rowLayoutAt(rowIndex)
        .contentSpan
        .height;

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
      fixture.arrangerViewModel.trackLayout
          .rowLayoutAt(rowIndex)
          .contentSpan
          .height,
      greaterThan(initialHeight),
    );
  });

  testWidgets('places header content, indicators, and dividers from layout', (
    tester,
  ) async {
    final fixture = _TrackHeadersTestFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });

    await fixture.pump(tester);

    final trackLayout = fixture.arrangerViewModel.trackLayout;
    final rowLayout = trackLayout.rowLayoutForId(fixture.trackId);
    final indicatorLayout = trackLayout.colorIndicatorLayouts.firstWhere(
      (indicator) => indicator.rowId == fixture.trackId,
    );
    final dividerLayout = trackLayout.dividerLayouts.firstWhere(
      (divider) => divider.resizedRowId == fixture.trackId,
    );
    final origin = tester.getTopLeft(
      find.byKey(_TrackHeadersTestFixture.headerAreaKey),
    );

    expect(
      tester.getRect(find.byKey(Key(fixture.trackId.toString()))),
      rowLayout.headerBounds.shift(origin),
    );
    expect(
      tester.getRect(find.byKey(Key('${fixture.trackId}-indicator'))),
      indicatorLayout.bounds.shift(origin),
    );

    final visualDividerRect = tester.getRect(
      find.byKey(Key('${fixture.trackId}-divider-visual')),
    );
    expect(visualDividerRect, dividerLayout.bounds.shift(origin));

    final dividerHitRect = tester.getRect(
      find.byKey(Key('${fixture.trackId}-handle')),
    );
    expect(dividerHitRect.center, visualDividerRect.center);
    expect(dividerHitRect.height, visualDividerRect.height + 10);
  });

  testWidgets(
    'keeps a group indicator while laying out visible descendants independently',
    (tester) async {
      final fixture = _TrackHeadersTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      final groupTrackId = fixture.createScrollableGroup();
      final trackLayout = fixture.arrangerViewModel.trackLayout;
      final groupLayout = trackLayout.rowLayoutForId(groupTrackId);
      final firstChildId =
          fixture.project.tracks[groupTrackId]!.childTracks.first;

      fixture.setVerticalScrollPosition(groupLayout.headerBounds.bottom);
      await fixture.pump(tester);

      expect(find.byKey(Key(groupTrackId.toString())), findsNothing);
      expect(find.byKey(Key(firstChildId.toString())), findsOneWidget);
      expect(find.byKey(Key('$groupTrackId-indicator')), findsOneWidget);
    },
  );

  testWidgets('culls each header at its own calculated bounds', (tester) async {
    final fixture = _TrackHeadersTestFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });

    final groupTrackId = fixture.createScrollableGroup();
    final trackLayout = fixture.arrangerViewModel.trackLayout;
    final groupBottom = trackLayout
        .rowLayoutForId(groupTrackId)
        .headerBounds
        .bottom;

    fixture.setVerticalScrollPosition(groupBottom - 1);
    await fixture.pump(tester);

    expect(find.byKey(Key(groupTrackId.toString())), findsOneWidget);

    fixture.setVerticalScrollPosition(groupBottom);
    await fixture.pump(tester);

    expect(find.byKey(Key(groupTrackId.toString())), findsNothing);
  });
}

class _TrackHeadersTestFixture {
  static const viewSize = Size(190, 260);
  static const headerAreaKey = Key('track-headers-test-area');

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
    refreshLayout();
    return phantomLane;
  }

  Id createScrollableGroup() {
    final initialTrackId = project.trackOrder.first;
    final groupTrack = TrackModel(
      idAllocator: project.idAllocator,
      name: 'Group',
      color: .new(hue: 0, palette: .grayscale),
      type: .group,
    );

    project.tracks[initialTrackId]!.parentTrackId = groupTrack.id;
    groupTrack.childTracks.add(initialTrackId);
    project.tracks[groupTrack.id] = groupTrack;
    project.trackOrder[0] = groupTrack.id;
    arrangerViewModel.registerTrack(groupTrack.id);

    TrackModel createTrack(String name) => TrackModel(
      idAllocator: project.idAllocator,
      name: name,
      color: .new(hue: 0, palette: .grayscale),
      type: .normal,
    );

    for (var i = 0; i < 2; i++) {
      final childTrack = createTrack('Child $i')..parentTrackId = groupTrack.id;
      project.tracks[childTrack.id] = childTrack;
      groupTrack.childTracks.add(childTrack.id);
      arrangerViewModel.registerTrack(childTrack.id);
    }
    for (var i = 0; i < 10; i++) {
      final trailingTrack = createTrack('Trailing $i');
      project.tracks[trailingTrack.id] = trailingTrack;
      project.trackOrder.add(trailingTrack.id);
      arrangerViewModel.registerTrack(trailingTrack.id);
    }

    refreshLayout();
    return groupTrack.id;
  }

  void setVerticalScrollPosition(double position) {
    arrangerViewModel.verticalScrollPosition = position;
    refreshLayout();
  }

  void refreshLayout() {
    arrangerViewModel.refreshTrackLayout(
      viewSize.height,
      headerWidth: viewSize.width,
    );
  }

  Future<void> pump(WidgetTester tester) async {
    refreshLayout();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProjectModel>.value(value: project),
          Provider<ArrangerViewModel>.value(value: arrangerViewModel),
          Provider<ArrangerController>.value(
            value: serviceRegistry.arrangerController,
          ),
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
              key: headerAreaKey,
              width: viewSize.width,
              height: viewSize.height,
              child: TrackHeaders(
                verticalScrollPosition:
                    arrangerViewModel.verticalScrollPosition,
              ),
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
