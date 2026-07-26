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
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/slider.dart' as anthem;
import 'package:anthem/widgets/basic/icon.dart';
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

  group('automation lanes', () {
    testWidgets('indicator button toggles expansion without existing lanes', (
      tester,
    ) async {
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
      final buttonFinder = _automationLaneButtonFinder(fixture.trackId);
      expect(buttonFinder, findsOneWidget);

      var button = tester.widget<Button>(buttonFinder);
      expect(button.icon, same(Icons.track.automationAdd));

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(
        fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId],
        isTrue,
      );
      button = tester.widget<Button>(buttonFinder);
      expect(button.icon, same(Icons.track.automationExpanded));

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(
        fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId],
        isFalse,
      );
      button = tester.widget<Button>(buttonFinder);
      expect(button.icon, same(Icons.track.automationAdd));
    });

    testWidgets('indicator button reflects existing automation lanes', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      fixture.addToneGeneratorAutomationLane(
        deviceName: 'Tone Generator',
        laneName: 'Filter Sweep',
      );
      fixture.arrangerViewModel.automationExpandedByTrackId[fixture.trackId] =
          false;
      await fixture.pump(tester);

      final buttonFinder = _automationLaneButtonFinder(fixture.trackId);
      var button = tester.widget<Button>(buttonFinder);
      expect(button.icon, same(Icons.track.automationCollapsed));

      await tester.tap(buttonFinder);
      await tester.pump();

      button = tester.widget<Button>(buttonFinder);
      expect(button.icon, same(Icons.track.automationExpanded));
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

      final phantomLane = fixture.arrangerViewModel
          .phantomAutomationLaneForTrack(fixture.trackId)!;

      await fixture.pump(tester);

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

      final automationLaneHeader = find.byKey(
        Key(automationLaneInfo.laneId.toString()),
      );
      await tester.tapAt(
        tester.getCenter(automationLaneHeader),
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
      expect(automationLaneHeader, findsNothing);
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

  group('automation lane value slider', () {
    testWidgets('is vertical and bound to the automated parameter', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      final laneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: 'Tone Generator',
        laneName: 'Filter Sweep',
      );
      await fixture.pump(tester);

      final lane = fixture.project.tracks[laneInfo.laneId]!;
      final target = lane.automationTarget!;
      final slider = tester.widget<anthem.Slider>(
        _automationSliderFinder(lane.id),
      );

      expect(slider.axis, anthem.SliderAxis.vertical);
      expect(slider.width, 15);
      expect(slider.parameter?.node.id, target.nodeId);
      expect(slider.parameter?.port.id, target.portId);
      expect(
        slider.parameter?.automationVisualizationId,
        lane
            .requireAutomationProcessing
            .controlValueVisualizationProcessor
            ?.visualizationId,
      );
    });

    testWidgets('changes size in sync with the regular track meter', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      final laneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: 'Tone Generator',
        laneName: 'Filter Sweep',
      );
      final meterFinder = _volumeMeterFinder(fixture.trackId);
      final sliderFinder = _automationSliderFinder(laneInfo.laneId);

      Future<void> expectControlHeights({
        required double modifier,
        required double meterHeight,
        required double sliderHeight,
      }) async {
        fixture.arrangerViewModel.setRowHeightModifier(
          fixture.trackId,
          modifier,
        );
        fixture.arrangerViewModel.setRowHeightModifier(
          laneInfo.laneId,
          modifier,
        );
        await fixture.pump(tester);

        expect(tester.getSize(meterFinder).height, meterHeight);
        expect(tester.getSize(sliderFinder).height, sliderHeight);
      }

      await expectControlHeights(
        modifier: 0.99,
        meterHeight: 20,
        sliderHeight: 20,
      );
      await expectControlHeights(
        modifier: 1,
        meterHeight: 44,
        sliderHeight: 34,
      );
      await expectControlHeights(
        modifier: 1.49,
        meterHeight: 44,
        sliderHeight: 34,
      );
      await expectControlHeights(
        modifier: 1.5,
        meterHeight: 68,
        sliderHeight: 55,
      );
      expect(
        tester.getRect(sliderFinder).right,
        tester.getRect(meterFinder).right,
      );
    });

    testWidgets('is omitted when the stored target is unavailable', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      final laneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: 'Tone Generator',
        laneName: 'Filter Sweep',
      );
      final lane = fixture.project.tracks[laneInfo.laneId]!;
      lane.automationTarget!.nodeId = 999999;

      await fixture.pump(tester);

      expect(_automationSliderFinder(lane.id), findsNothing);
    });

    testWidgets('remains vertically centered in larger header sizes', (
      tester,
    ) async {
      final fixture = _TrackHeaderTestFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      });

      final laneInfo = fixture.addToneGeneratorAutomationLane(
        deviceName: 'Tone Generator',
        laneName: 'Filter Sweep',
      );
      final headerFinder = find.byKey(Key(laneInfo.laneId.toString()));
      final sliderFinder = _automationSliderFinder(laneInfo.laneId);

      for (final modifier in [1.25, 1.75]) {
        fixture.arrangerViewModel.setRowHeightModifier(
          laneInfo.laneId,
          modifier,
        );
        await fixture.pump(tester);

        expect(
          tester.getRect(sliderFinder).center.dy,
          closeTo(tester.getRect(headerFinder).center.dy, 0.000001),
        );
      }
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

Finder _automationLaneButtonFinder(Id trackId) => find
    .descendant(
      of: find.byKey(Key('$trackId-indicator')),
      matching: find.byType(Button),
    )
    .at(1);

Finder _automationSliderFinder(Id trackId) => find.descendant(
  of: find.byKey(Key(trackId.toString())),
  matching: find.byType(anthem.Slider),
);

Finder _volumeMeterFinder(Id trackId) => find.descendant(
  of: find.byKey(Key(trackId.toString())),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;

    final decoration = widget.decoration;
    return widget.constraints?.minWidth == 15 &&
        widget.constraints?.maxWidth == 15 &&
        decoration is BoxDecoration &&
        decoration.border != null;
  }),
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
