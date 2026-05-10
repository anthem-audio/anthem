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
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_header.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('single click selects the track without opening an editor', (
    tester,
  ) async {
    final fixture = _TrackHeaderTestFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    await fixture.pump(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await fixture.clickHeader(tester, mouse);

    expect(fixture.arrangerViewModel.selectedTracks, contains(fixture.trackId));
    expect(fixture.arrangerViewModel.selectedTracks, hasLength(1));
    expect(fixture.projectViewModel.selectedEditor, isNull);
    expect(fixture.projectViewModel.activePanel, isNull);
  });

  testWidgets('double-click opens the device rack for the clicked track', (
    tester,
  ) async {
    final fixture = _TrackHeaderTestFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    await fixture.pump(tester);

    fixture.projectViewModel.selectedEditor = EditorKind.mixer;
    fixture.projectViewModel.activePanel = PanelKind.mixer;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await fixture.clickHeader(tester, mouse);
    await tester.pump(const Duration(milliseconds: 10));
    await fixture.clickHeader(tester, mouse);

    expect(fixture.arrangerViewModel.selectedTracks, contains(fixture.trackId));
    expect(fixture.arrangerViewModel.selectedTracks, hasLength(1));
    expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
    expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
  });
}

class _TrackHeaderTestFixture {
  static const headerKey = Key('track-header-under-test');
  static const viewSize = Size(190, 80);

  final ProjectModel project;

  _TrackHeaderTestFixture._(this.project);

  factory _TrackHeaderTestFixture.create() {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);

    final fixture = _TrackHeaderTestFixture._(project);
    fixture.arrangerViewModel.trackPositionCalculator.invalidate(
      viewSize.height,
    );

    return fixture;
  }

  ServiceRegistry get serviceRegistry => ServiceRegistry.forProject(project.id);

  ProjectViewModel get projectViewModel => serviceRegistry.projectViewModel;

  ArrangerViewModel get arrangerViewModel => serviceRegistry.arrangerViewModel;

  Id get trackId => project.trackOrder.first;

  Future<void> pump(WidgetTester tester) async {
    arrangerViewModel.trackPositionCalculator.invalidate(viewSize.height);

    await tester.pumpWidget(
      Provider<ProjectModel>.value(
        value: project,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: headerKey,
              width: viewSize.width,
              height: viewSize.height,
              child: TrackHeader(trackId: trackId),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> clickHeader(WidgetTester tester, TestGesture mouse) async {
    final position =
        tester.getTopLeft(find.byKey(headerKey)) + const Offset(28, 20);

    await mouse.down(position);
    await tester.pump();
    await mouse.up();
    await tester.pump();
  }

  void dispose() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  }
}
