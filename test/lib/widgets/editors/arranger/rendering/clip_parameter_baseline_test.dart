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

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_geometry.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the same pattern shades from each target baseline in a batched render',
    () async {
      final project = ProjectModel.create();
      ServiceRegistry.initializeProject(project);
      addTearDown(() {
        ServiceRegistry.removeProject(project.id);
        project.dispose();
      });
      final track = project.tracks[project.trackOrder.single]!;
      final node = track.requireProcessing.utilityNode!;
      for (final portId in [
        UtilityProcessorModel.balancePortId,
        UtilityProcessorModel.gainPortId,
      ]) {
        AutomationLaneAddRemoveCommand.add(
          project: project,
          parentTrackId: track.id,
          nodeId: node.id,
          portId: portId,
          name: 'Parameter',
          index: track.automationLanes.length,
        ).execute(project);
      }
      final pattern = PatternModel(
        idAllocator: project.idAllocator,
        name: 'Automation',
      );
      project.sequence.patterns[pattern.id] = pattern;
      final clips = [
        for (var i = 0; i < track.automationLanes.length; i++)
          ClipRenderInfo(
            pattern: pattern,
            color: track.color,
            clipId: project.allocateId(),
            trackId: track.automationLanes[i],
            hasTimingOverride: false,
            clipOffset: 0,
            clipTimeViewStart: 0,
            clipTimeViewEnd: 100,
            x: 0,
            y: i * 100.0,
            width: 101,
            height: 86,
            selected: false,
            hovered: false,
          ),
      ];
      final background = await _paintClips(project, clips);
      pattern.automation.points.addAll([
        for (final offset in [0, 100])
          AutomationPointModel(
            idAllocator: project.idAllocator,
            offset: offset,
            value: 0.25,
          ),
      ]);
      final pixels = await _paintClips(project, clips);
      List<int> pixel(Uint8List data, int row, double fraction) {
        final bounds = automationContentVerticalBoundsForClip(
          clipTop: row * 100.0,
          clipHeight: 86,
        );
        final y = (bounds.top + (bounds.bottom - bounds.top) * fraction)
            .floor();
        final offset = (y * 110 + 50) * 4;
        return data.sublist(offset, offset + 4);
      }

      // Pan shades between value 0.25 and neutral 0.5, excluding the lower region.
      expect(
        pixel(pixels, 0, 0.625),
        isNot(orderedEquals(pixel(background, 0, 0.625))),
      );
      expect(pixel(pixels, 0, 0.9), orderedEquals(pixel(background, 0, 0.9)));
      // Gain shades to the minimum even though its reset default is -10 dB.
      expect(
        pixel(pixels, 1, 0.625),
        orderedEquals(pixel(background, 1, 0.625)),
      );
      expect(
        pixel(pixels, 1, 0.9),
        isNot(orderedEquals(pixel(background, 1, 0.9))),
      );

      // Display formatting does not select the fill baseline, even for bipolar
      // percentages. The same stored baseline keeps the pixels identical.
      final panConfig = node
          .getPortById(UtilityProcessorModel.balancePortId)
          .config
          .parameterConfig!;
      panConfig.displayMode = ParameterDisplayMode.percent;
      final percentages = await _paintClips(project, clips);
      expect(percentages, orderedEquals(pixels));
      node
              .getPortById(UtilityProcessorModel.balancePortId)
              .config
              .parameterConfig!
              .normalizedVisualBaseline =
          0.1;
      final offCenter = await _paintClips(project, clips);
      expect(
        pixel(offCenter, 0, 0.825),
        isNot(orderedEquals(pixel(background, 0, 0.825))),
      );
      expect(
        pixel(offCenter, 0, 0.625),
        orderedEquals(pixel(background, 0, 0.625)),
      );

      // A removed or unresolved plugin port falls back to minimum shading.
      project.tracks[clips.first.trackId]!.automationTarget!.portId = -1;
      final unresolved = await _paintClips(project, clips);
      expect(
        pixel(unresolved, 0, 0.9),
        isNot(orderedEquals(pixel(background, 0, 0.9))),
      );
    },
  );

  test(
    'single clip rendering honors an explicit off-center baseline',
    () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final track = project.tracks[project.trackOrder.single]!;
      final pattern = PatternModel(
        idAllocator: project.idAllocator,
        name: 'Automation',
      );
      project.sequence.patterns[pattern.id] = pattern;
      pattern.automation.points.addAll([
        for (final offset in [0, 100])
          AutomationPointModel(
            idAllocator: project.idAllocator,
            offset: offset,
            value: 0.5,
          ),
      ]);
      Future<Uint8List> render(double baseline) async {
        final recorder = ui.PictureRecorder();
        paintClip(
          canvas: ui.Canvas(recorder),
          canvasSize: const ui.Size(110, 86),
          pattern: pattern,
          color: track.color,
          x: 0,
          y: 0,
          width: 101,
          height: 86,
          selected: false,
          timeViewStart: 0,
          timeViewEnd: 110,
          normalizedVisualBaseline: baseline,
        );
        return _pixels(recorder, 110, 86);
      }

      final neutral = await render(0.5);
      final offCenter = await render(0.25);
      final minimum = await render(0);
      final bounds = automationContentVerticalBoundsForClip(
        clipTop: 0,
        clipHeight: 86,
      );
      List<int> pixel(Uint8List data, double fraction) {
        final y = (bounds.top + (bounds.bottom - bounds.top) * fraction)
            .floor();
        final offset = (y * 110 + 50) * 4;
        return data.sublist(offset, offset + 4);
      }

      expect(
        pixel(offCenter, 0.625),
        isNot(orderedEquals(pixel(neutral, 0.625))),
      );
      expect(pixel(offCenter, 0.9), orderedEquals(pixel(neutral, 0.9)));
      expect(pixel(minimum, 0.9), isNot(orderedEquals(pixel(neutral, 0.9))));
    },
  );
}

Future<Uint8List> _paintClips(
  ProjectModel project,
  List<ClipRenderInfo> clips,
) async {
  final recorder = ui.PictureRecorder();
  paintClipList(
    project: project,
    canvas: ui.Canvas(recorder),
    canvasSize: const ui.Size(110, 200),
    automationHandleAnnotations: AutomationHandleAnnotationSet(),
    hoveredAutomationHandle: null,
    clipList: clips,
    devicePixelRatio: 1,
    timeViewStart: 0,
    timeViewEnd: 110,
  );
  return _pixels(recorder, 110, 200);
}

Future<Uint8List> _pixels(
  ui.PictureRecorder recorder,
  int width,
  int height,
) async {
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  image.dispose();
  return bytes;
}
