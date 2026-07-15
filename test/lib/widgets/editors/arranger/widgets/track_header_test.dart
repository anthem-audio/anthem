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
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_headers.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ServiceRegistry.screenOverlayController = _screenOverlayController;

  group('automation lane button', () {
    testWidgets('appears while hovered or expanded', (tester) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await fixture.pump(tester);

      expect(_automationLaneButtonFinder, findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await fixture.hoverTrackContent(tester, mouse);

      expect(_automationLaneButtonFinder, findsOneWidget);

      await mouse.moveTo(const Offset(400, 400));
      await tester.pump();

      expect(_automationLaneButtonFinder, findsNothing);

      fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId] =
          true;
      await fixture.pump(tester);

      expect(_automationLaneButtonFinder, findsOneWidget);
    });

    testWidgets('pins to the bottom-left of the track content', (tester) async {
      final fixture = _TrackHeaderTestFixture.create(baseTrackHeight: 70);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await fixture.pump(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await fixture.hoverTrackContent(tester, mouse);

      final contentBoxRect = fixture.trackFixedContentRect(tester);
      final backgroundRect = tester.getRect(
        _automationLaneButtonBackgroundFinder,
      );
      final buttonRect = tester.getRect(_automationLaneButtonFinder);
      final background = tester.widget<Container>(
        _automationLaneButtonBackgroundFinder,
      );

      expect(background.color, AnthemTheme.panel.main);
      expect(backgroundRect.left, contentBoxRect.left - 4);
      expect(backgroundRect.bottom, contentBoxRect.bottom + 4);
      expect(backgroundRect.width, 28);
      expect(backgroundRect.height, 28);
      expect(buttonRect.left, contentBoxRect.left);
      expect(buttonRect.bottom, contentBoxRect.bottom);
    });

    testWidgets('centers vertically in the compact track layout', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create(baseTrackHeight: 40);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await fixture.pump(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await fixture.hoverTrackContent(tester, mouse);

      final contentBoxRect = fixture.trackFixedContentRect(tester);
      final buttonRect = tester.getRect(_automationLaneButtonFinder);

      expect(buttonRect.left, contentBoxRect.left);
      expect(buttonRect.center.dy, moreOrLessEquals(contentBoxRect.center.dy));
    });

    testWidgets('insets compact expanded title around the visible button', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create(baseTrackHeight: 40);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId] =
          true;
      await fixture.pump(tester);

      final titleRect = tester.getRect(find.text('Track 1'));
      final buttonBackgroundRect = tester.getRect(
        _automationLaneButtonBackgroundFinder,
      );

      expect(titleRect.left, greaterThanOrEqualTo(buttonBackgroundRect.right));
    });

    testWidgets('does not pass clicks through to the track header', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await fixture.pump(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await fixture.hoverTrackContent(tester, mouse);
      await mouse.down(tester.getCenter(_automationLaneButtonFinder));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(
        fixture.arrangerViewModel.selectedTracks,
        isNot(contains(fixture.trackId)),
      );
    });

    testWidgets('toggles the track automation expansion state', (tester) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });
      await fixture.pump(tester);

      expect(
        fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId],
        isFalse,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await fixture.hoverTrackContent(tester, mouse);

      expect(
        tester.widget<Button>(_automationLaneButtonFinder).toggleState,
        isFalse,
      );

      await fixture.clickAutomationLaneButton(tester, mouse);

      expect(
        fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId],
        isTrue,
      );
      expect(
        tester.widget<Button>(_automationLaneButtonFinder).toggleState,
        isTrue,
      );

      await fixture.clickAutomationLaneButton(tester, mouse);

      expect(
        fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId],
        isFalse,
      );
      expect(
        tester.widget<Button>(_automationLaneButtonFinder).toggleState,
        isFalse,
      );
    });

    testWidgets('phantom lane shows parameter above device name', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId] =
          true;
      fixture.arrangerViewModel.lastTweakedAutomationTarget =
          AutomationParameterTarget(
            ownerTrackId: fixture.trackId,
            nodeId: 100,
            portId: 1,
            ownerName: 'Very Long Device Name That Needs More Space',
            parameterName: 'Cutoff',
          );

      await fixture.pump(tester);

      final phantomLane = fixture.arrangerViewModel
          .phantomAutomationLaneForTrack(fixture.trackId)!;
      expect(
        fixture.arrangerViewModel.trackLayout.tryRowLayoutForId(phantomLane.id),
        isNotNull,
      );
      final phantomRow =
          fixture.arrangerViewModel.trackLayout
                  .rowLayoutForId(phantomLane.id)
                  .row
              as PhantomAutomationTrackRow;
      expect(phantomRow.phantomLane.target?.parameterName, 'Cutoff');
      expect(find.byKey(Key('phantom-${phantomLane.id}')), findsOneWidget);
      expect(find.text('Cutoff'), findsOneWidget);
      expect(
        find.text('Very Long Device Name That Needs More Space'),
        findsOneWidget,
      );
      expect(
        find.text('Very Long Device Name That Needs More Space Cutoff'),
        findsNothing,
      );
    });

    testWidgets('real automation lane shows track title above target owner', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      const deviceName = 'Very Long Device Name That Needs More Space';
      const laneName = 'Filter Sweep';
      final automationLaneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: deviceName,
        laneName: laneName,
      );

      await fixture.pump(tester);

      final automationLane = fixture.project.tracks[automationLaneInfo.laneId]!;
      expect(automationLane.name, equals(laneName));
      expect(find.text(laneName), findsOneWidget);
      expect(find.text(deviceName), findsOneWidget);
      expect(find.text(automationLaneInfo.parameterName), findsNothing);
      expect(find.text('$deviceName $laneName'), findsNothing);
    });

    testWidgets('automation lane context menu only shows delete', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      const deviceName = 'Tone Generator';
      const laneName = 'Filter Sweep';
      final automationLaneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: deviceName,
        laneName: laneName,
      );

      await fixture.pump(tester);

      await tester.tapAt(
        tester.getCenter(find.text(laneName)),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Insert track'), findsNothing);
      expect(find.text('Group'), findsNothing);

      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(fixture.project.tracks[automationLaneInfo.laneId], isNull);
      expect(fixture.project.tracks[fixture.trackId]!.automationLanes, isEmpty);
      expect(find.text(laneName), findsNothing);
    });

    testWidgets('compact automation lane label renders on one row', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create(baseTrackHeight: 40);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      const deviceName = 'Very Long Device Name That Needs More Space';
      const laneName = 'Filter Sweep Automation Name That Needs Space';
      fixture.addToneGeneratorAutomationLane(
        deviceName: deviceName,
        laneName: laneName,
      );

      await fixture.pump(tester);

      final compactLabelText = '$laneName  $deviceName';
      final compactLabelFinder = find.byWidgetPredicate((widget) {
        if (widget is! Text) {
          return false;
        }

        return widget.textSpan?.toPlainText() == compactLabelText &&
            widget.maxLines == 1 &&
            widget.overflow == TextOverflow.ellipsis &&
            widget.softWrap == false;
      });

      expect(compactLabelFinder, findsOneWidget);
      expect(find.text(laneName), findsNothing);
      expect(find.text(deviceName), findsNothing);
    });
  });

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

final _automationLaneButtonFinder = find.byKey(
  const ValueKey<String>('track-header-automation-lane-button'),
);

final _automationLaneButtonBackgroundFinder = find.byKey(
  const ValueKey<String>('track-header-automation-lane-button-background'),
);

final _screenOverlayViewModel = ScreenOverlayViewModel();
final _screenOverlayController = ScreenOverlayController(
  viewModel: _screenOverlayViewModel,
);

class _TrackHeaderTestFixture {
  static const headerKey = Key('track-header-under-test');
  static const viewSize = Size(190, 260);

  final ProjectModel project;

  _TrackHeaderTestFixture._(this.project);

  factory _TrackHeaderTestFixture.create({double? baseTrackHeight}) {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);

    final fixture = _TrackHeaderTestFixture._(project);
    if (baseTrackHeight != null) {
      fixture.arrangerViewModel.baseTrackHeight = baseTrackHeight;
    }
    fixture.arrangerViewModel.refreshTrackLayout(
      viewSize.height,
      headerWidth: viewSize.width,
    );

    return fixture;
  }

  ServiceRegistry get serviceRegistry => ServiceRegistry.forProject(project.id);

  ProjectViewModel get projectViewModel => serviceRegistry.projectViewModel;

  ArrangerViewModel get arrangerViewModel => serviceRegistry.arrangerViewModel;

  Id get trackId => project.trackOrder.first;

  double get trackHeight =>
      arrangerViewModel.trackLayout.rowLayoutForId(trackId).contentSpan.height;

  ({Id laneId, String parameterName}) addToneGeneratorAutomationLane({
    required String deviceName,
    required String laneName,
  }) {
    final track = project.tracks[trackId]!;
    final createResult = DeviceFactories.create(
      idAllocator: project.idAllocator,
      descriptor: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
    );
    final device = createResult.device;
    device.name = deviceName;
    track.requireProcessing.devices.add(device);
    for (final node in createResult.graphFragment.nodes) {
      node.owner = NodeOwnerModel(trackId: track.id, deviceId: device.id);
    }
    project.processingGraph.restoreGraphFragment(createResult.graphFragment);

    final parameterName =
        'Parameter ${ToneGeneratorProcessorModel.frequencyPortId}';

    AutomationLaneAddRemoveCommand.add(
      project: project,
      parentTrackId: track.id,
      nodeId: device.nodeIds.single,
      portId: ToneGeneratorProcessorModel.frequencyPortId,
      name: parameterName,
    ).execute(project);

    final laneId = track.automationLanes.single;
    project.tracks[laneId]!.name = laneName;
    arrangerViewModel.automationExpandedByTrackId[trackId] = true;

    return (laneId: laneId, parameterName: parameterName);
  }

  Future<void> pump(WidgetTester tester) async {
    arrangerViewModel.refreshTrackLayout(
      viewSize.height,
      headerWidth: viewSize.width,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MultiProvider(
          providers: [
            Provider<ProjectModel>.value(value: project),
            Provider<ArrangerViewModel>.value(value: arrangerViewModel),
            Provider<ArrangerController>.value(
              value: serviceRegistry.arrangerController,
            ),
            Provider<ScreenOverlayController>.value(
              value: _screenOverlayController,
            ),
            Provider<ScreenOverlayViewModel>.value(
              value: _screenOverlayViewModel,
            ),
          ],
          child: Observer(
            builder: (context) {
              final overlayEntries = _screenOverlayViewModel.entries.entries
                  .toList(growable: false);

              return Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        key: headerKey,
                        width: viewSize.width,
                        height: viewSize.height,
                        child: TrackHeaders(verticalScrollPosition: 0),
                      ),
                    ),
                  ),
                  if (overlayEntries.isNotEmpty)
                    Positioned.fill(
                      child: Listener(
                        onPointerUp: (_) => _screenOverlayController.clear(),
                        onPointerCancel: (_) =>
                            _screenOverlayController.clear(),
                        child: Container(color: const Color(0x00000000)),
                      ),
                    ),
                  ...overlayEntries.map(
                    (entry) => entry.value.builder(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  Rect trackContentRect(WidgetTester tester) {
    final headerTopLeft = tester.getTopLeft(find.byKey(headerKey));
    final bounds = arrangerViewModel.trackLayout
        .rowLayoutForId(trackId)
        .headerBounds;

    return Rect.fromLTWH(
      headerTopLeft.dx + bounds.left,
      headerTopLeft.dy + bounds.top,
      bounds.width,
      bounds.height,
    );
  }

  Rect trackFixedContentRect(WidgetTester tester) {
    final trackContentRect = this.trackContentRect(tester);
    final contentHeight = switch (trackContentRect.height) {
      >= 78 => 68.0,
      >= 52 => 44.0,
      _ => 20.0,
    };

    return Rect.fromLTWH(
      trackContentRect.left + 4,
      trackContentRect.top + (trackContentRect.height - contentHeight) / 2,
      trackContentRect.width - 8,
      contentHeight,
    );
  }

  Future<void> hoverTrackContent(WidgetTester tester, TestGesture mouse) async {
    await mouse.moveTo(trackContentRect(tester).center);
    await tester.pump();
  }

  Future<void> clickAutomationLaneButton(
    WidgetTester tester,
    TestGesture mouse,
  ) async {
    await mouse.down(tester.getCenter(_automationLaneButtonFinder));
    await tester.pump();
    await mouse.up();
    await tester.pump();
  }

  Future<void> clickHeader(WidgetTester tester, TestGesture mouse) async {
    final position = trackContentRect(tester).topLeft + const Offset(19, 20);

    await mouse.down(position);
    await tester.pump();
    await mouse.up();
    await tester.pump();
  }

  void dispose() {
    _screenOverlayController.clear();
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  }
}
