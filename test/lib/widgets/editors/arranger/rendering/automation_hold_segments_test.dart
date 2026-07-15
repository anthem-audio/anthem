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

import 'dart:ui' as ui;

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/rendering/automation_hold_renderer.dart';
import 'package:anthem/widgets/editors/arranger/automation_hold_segments.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildAutomationHoldSegments', () {
    test('renders held values only in gaps between clip bodies', () {
      final segments = _buildSegments([
        _clip(
          id: 1,
          offset: 0,
          width: 100,
          points: [_point(0, 0.2), _point(100, 0.7)],
        ),
        _clip(id: 2, offset: 150, width: 50),
        _clip(
          id: 3,
          offset: 300,
          width: 100,
          points: [_point(0, 0.1), _point(100, 0.4)],
        ),
      ]);

      _expectSegment(segments[0], start: 100, end: 150, value: 0.7);
      _expectSegment(segments[1], start: 200, end: 300, value: 0.7);
      _expectSegment(segments[2], start: 400, end: double.infinity, value: 0.4);
      expect(segments, hasLength(3));
    });

    test('uses first contributing automation clip value before first clip', () {
      final segments = _buildSegments([
        _clip(id: 1, offset: 20, width: 20),
        _clip(
          id: 2,
          offset: 100,
          width: 50,
          points: [_point(0, 0.3), _point(50, 0.6)],
        ),
      ]);

      _expectSegment(segments[0], start: 0, end: 20, value: 0.3);
      _expectSegment(segments[1], start: 40, end: 100, value: 0.3);
      _expectSegment(segments[2], start: 150, end: double.infinity, value: 0.6);
      expect(segments, hasLength(3));
    });

    test(
      'empty clips can truncate previous automation but do not set value',
      () {
        final segments = _buildSegments([
          _clip(
            id: 1,
            offset: 0,
            width: 100,
            points: [_point(0, 0.0), _point(100, 1.0)],
          ),
          _clip(id: 2, offset: 50, width: 10),
        ]);

        _expectSegment(
          segments.single,
          start: 100,
          end: double.infinity,
          value: 0.5,
        );
      },
    );

    test('later overlapping automation clip determines later held value', () {
      final segments = _buildSegments([
        _clip(
          id: 1,
          offset: 0,
          width: 100,
          points: [_point(0, 0.0), _point(100, 1.0)],
        ),
        _clip(
          id: 2,
          offset: 50,
          width: 30,
          points: [_point(0, 0.8), _point(30, 0.9)],
        ),
      ]);

      _expectSegment(
        segments.single,
        start: 100,
        end: double.infinity,
        value: 0.9,
      );
    });

    test('same-offset lower-id automation clip is deconflicted away', () {
      final segments = _buildSegments([
        _clip(
          id: 1,
          offset: 0,
          width: 100,
          points: [_point(0, 0.1), _point(100, 0.2)],
        ),
        _clip(
          id: 2,
          offset: 0,
          width: 50,
          points: [_point(0, 0.8), _point(50, 0.9)],
        ),
      ]);

      _expectSegment(
        segments.single,
        start: 100,
        end: double.infinity,
        value: 0.9,
      );
    });

    test('single-point automation holds that value', () {
      final segments = _buildSegments([
        _clip(id: 1, offset: 0, width: 50, points: [_point(0, 0.4)]),
      ]);

      _expectSegment(
        segments.single,
        start: 50,
        end: double.infinity,
        value: 0.4,
      );
    });

    test('clipped automation uses source range values for holds', () {
      final segments = _buildSegments([
        _clip(
          id: 1,
          offset: 100,
          width: 50,
          sourceStart: 50,
          sourceEnd: 100,
          points: [_point(0, 0.0), _point(100, 1.0)],
        ),
      ]);

      _expectSegment(segments[0], start: 0, end: 100, value: 0.5);
      _expectSegment(segments[1], start: 150, end: double.infinity, value: 1.0);
      expect(segments, hasLength(2));
    });

    test('returns no segments when no clip contributes automation', () {
      final segments = _buildSegments([
        _clip(id: 1, offset: 0, width: 50),
        _clip(id: 2, offset: 100, width: 50),
      ]);

      expect(segments, isEmpty);
    });
  });

  group('evaluateAutomationHoldValueAtSourceTick', () {
    test('evaluates clipped smooth source positions', () {
      final value = _evaluatePoints([_point(0, 0.0), _point(100, 1.0)], 50);

      expect(value, closeTo(0.5, 1e-9));
    });

    test('uses first value for hold, stairs, and wave segments', () {
      for (final curve in [
        AutomationCurveType.hold,
        AutomationCurveType.stairs,
        AutomationCurveType.wave,
      ]) {
        final value = _evaluatePoints([
          _point(0, 0.2),
          _point(100, 0.9, curve: curve),
        ], 50);

        expect(value, closeTo(0.2, 1e-9));
      }
    });
  });

  group('automationHoldValueAtTick', () {
    test('uses half-open segment bounds', () {
      final segments = [
        const AutomationHoldSegment(startTick: 0, endTick: 96, value: 0.2),
        const AutomationHoldSegment(
          startTick: 96,
          endTick: double.infinity,
          value: 0.7,
        ),
      ];

      expect(automationHoldValueAtTick(segments, 0), closeTo(0.2, 1e-9));
      expect(automationHoldValueAtTick(segments, 95.999), closeTo(0.2, 1e-9));
      expect(automationHoldValueAtTick(segments, 96), closeTo(0.7, 1e-9));
    });

    test('returns null when no segment contains the tick', () {
      final segments = [
        const AutomationHoldSegment(startTick: 10, endTick: 20, value: 0.2),
      ];

      expect(automationHoldValueAtTick(segments, 0), isNull);
      expect(automationHoldValueAtTick(segments, 20), isNull);
    });
  });

  group('paintAutomationHoldSegments', () {
    test(
      'draws batched line and fill pixels for visible automation gaps',
      () async {
        final fixture = _AutomationHoldPaintFixture.create();
        addTearDown(fixture.dispose);

        fixture.viewModel.refreshTrackLayout(160);

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        paintAutomationHoldSegments(
          project: fixture.project,
          arrangement: fixture.arrangement,
          viewModel: fixture.viewModel,
          canvas: canvas,
          canvasSize: const ui.Size(500, 160),
          timeViewStart: 0,
          timeViewEnd: 500,
          renderedVerticalScrollPosition: 0,
        );

        final image = await recorder.endRecording().toImage(500, 160);
        final nonTransparentPixelCount = await _countNonTransparentPixels(
          image,
        );
        image.dispose();

        expect(nonTransparentPixelCount, greaterThan(0));
      },
    );

    test(
      'draws provider empty value for an automation lane with no clips',
      () async {
        final fixture = _AutomationHoldPaintFixture.create(
          withAutomationClips: false,
        );
        addTearDown(fixture.dispose);

        fixture.viewModel.refreshTrackLayout(160);

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        paintAutomationHoldSegments(
          project: fixture.project,
          arrangement: fixture.arrangement,
          viewModel: fixture.viewModel,
          canvas: canvas,
          canvasSize: const ui.Size(500, 160),
          timeViewStart: 0,
          timeViewEnd: 500,
          renderedVerticalScrollPosition: 0,
        );

        final image = await recorder.endRecording().toImage(500, 160);
        final nonTransparentPixelCount = await _countNonTransparentPixels(
          image,
        );
        image.dispose();

        expect(nonTransparentPixelCount, greaterThan(0));
      },
    );

    test(
      'draws current value line for targeted phantom automation lanes',
      () async {
        final fixture = _AutomationHoldPaintFixture.create(
          withAutomationClips: false,
        );
        addTearDown(fixture.dispose);

        final parentTrack = fixture.project.tracks.values.firstWhere(
          (track) => !track.isAutomationLane,
        );
        final utilityNode = parentTrack.requireProcessing.utilityNode!;
        final port = utilityNode.getPortById(UtilityProcessorModel.gainPortId);
        port.parameterValue = 0.25;

        fixture.viewModel.lastTweakedAutomationTarget =
            AutomationParameterTarget(
              ownerTrackId: parentTrack.id,
              nodeId: utilityNode.id,
              portId: UtilityProcessorModel.gainPortId,
              ownerName: 'Track',
              parameterName: 'Volume',
            );
        fixture.viewModel.refreshTrackLayout(160);

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        paintAutomationHoldSegments(
          project: fixture.project,
          arrangement: fixture.arrangement,
          viewModel: fixture.viewModel,
          canvas: canvas,
          canvasSize: const ui.Size(500, 160),
          timeViewStart: 0,
          timeViewEnd: 500,
          renderedVerticalScrollPosition: 0,
        );

        final image = await recorder.endRecording().toImage(500, 160);
        final nonTransparentPixelCount = await _countNonTransparentPixels(
          image,
        );
        image.dispose();

        expect(nonTransparentPixelCount, greaterThan(0));
      },
    );
  });

  group('buildAutomationHoldSegmentsForTrack', () {
    test('returns no segments for no-clip tracks', () {
      final fixture = _AutomationHoldPaintFixture.create(
        withAutomationClips: false,
      );
      addTearDown(fixture.dispose);

      final segments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );

      expect(segments, isEmpty);
    });

    test('reflects clips added after an empty render-time build', () {
      final fixture = _AutomationHoldPaintFixture.create(
        withAutomationClips: false,
      );
      addTearDown(fixture.dispose);

      final firstSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      expect(firstSegments, isEmpty);

      final pattern = _addPattern(fixture.project, 'A', [
        _point(0, 0.2),
        _point(96, 0.75),
      ]);
      _addClip(
        project: fixture.project,
        arrangement: fixture.arrangement,
        patternId: pattern.id,
        trackId: fixture.lane.id,
        offset: 0,
        start: 0,
        end: 96,
      );

      final updatedSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );

      _expectSegment(
        updatedSegments.single,
        start: 96,
        end: double.infinity,
        value: 0.75,
      );
    });

    test('reflects clips removed after a previous render-time build', () {
      final fixture = _AutomationHoldPaintFixture.create();
      addTearDown(fixture.dispose);

      final firstSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(firstSegments[0], start: 96, end: 144, value: 0.75);

      for (final clipId in fixture.arrangement.clips.keys.toList()) {
        fixture.arrangement.clips.remove(clipId);
      }

      expect(fixture.arrangement.hasClipsForTrack(fixture.lane.id), isFalse);
      expect(
        buildAutomationHoldSegmentsForTrack(
          project: fixture.project,
          arrangement: fixture.arrangement,
          trackId: fixture.lane.id,
        ),
        isEmpty,
      );
    });

    test('reflects pattern automation changes', () {
      final fixture = _AutomationHoldPaintFixture.create();
      addTearDown(fixture.dispose);

      final firstSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(firstSegments[0], start: 96, end: 144, value: 0.75);

      final firstClip = fixture.arrangement.clips.values.firstWhere(
        (clip) => clip.offset == 0,
      );
      final pattern = fixture.project.sequence.patterns[firstClip.patternId]!;
      pattern.automation.points.last.value = 0.5;

      final updatedSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(updatedSegments[0], start: 96, end: 144, value: 0.5);
    });

    test('reflects clip timing changes', () {
      final fixture = _AutomationHoldPaintFixture.create();
      addTearDown(fixture.dispose);

      final firstSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(firstSegments[0], start: 96, end: 144, value: 0.75);

      final firstClip = fixture.arrangement.clips.values.firstWhere(
        (clip) => clip.offset == 0,
      );
      firstClip.offset = 24;

      final updatedSegments = buildAutomationHoldSegmentsForTrack(
        project: fixture.project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(updatedSegments[0], start: 0, end: 24, value: 0.2);
    });

    test('reflects clip moves between tracks', () {
      final fixture = _AutomationHoldPaintFixture.create();
      addTearDown(fixture.dispose);

      final project = fixture.project;
      final parentTrack = project.tracks[project.trackOrder.first]!;
      final destinationLane = _addAutomationLane(
        project: project,
        parentTrack: parentTrack,
        name: 'Resonance',
        hue: 200,
      );

      final sourceSegments = buildAutomationHoldSegmentsForTrack(
        project: project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(sourceSegments[0], start: 96, end: 144, value: 0.75);

      final movedClip = fixture.arrangement.clips.values.firstWhere(
        (clip) => clip.offset == 0,
      );
      movedClip.trackId = destinationLane.id;

      final updatedSourceSegments = buildAutomationHoldSegmentsForTrack(
        project: project,
        arrangement: fixture.arrangement,
        trackId: fixture.lane.id,
      );
      _expectSegment(updatedSourceSegments[0], start: 0, end: 144, value: 0.4);

      final destinationSegments = buildAutomationHoldSegmentsForTrack(
        project: project,
        arrangement: fixture.arrangement,
        trackId: destinationLane.id,
      );
      _expectSegment(
        destinationSegments.single,
        start: 96,
        end: double.infinity,
        value: 0.75,
      );
    });
  });
}

TrackModel _addAutomationLane({
  required ProjectModel project,
  required TrackModel parentTrack,
  required String name,
  required double hue,
}) {
  final lane = TrackModel(
    idAllocator: project.idAllocator,
    name: name,
    color: AnthemColor(hue: hue),
    type: TrackType.automationLane,
    automationTarget: TrackAutomationTargetModel.uninitialized(),
  )..automationLaneParentTrackId = parentTrack.id;

  project.tracks[lane.id] = lane;
  parentTrack.automationLanes.add(lane.id);
  ServiceRegistry.forProject(
    project.id,
  ).arrangerViewModel.registerTrack(lane.id);

  return lane;
}

typedef _ClipSpec = ({
  Id id,
  int offset,
  int width,
  int sourceStart,
  int? sourceEnd,
  List<_PointSpec> points,
});

typedef _PointSpec = ({int offset, double value, AutomationCurveType curve});

List<AutomationHoldSegment> _buildSegments(List<_ClipSpec> clipSpecs) {
  final project = ProjectModel.create();
  try {
    final sortedClipSpecs = clipSpecs.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    final clips = sortedClipSpecs
        .map((clipSpec) {
          final pattern = _addPattern(
            project,
            'Pattern ${clipSpec.id}',
            clipSpec.points,
          );

          return ClipModel(
            idAllocator: project.idAllocator,
            patternId: pattern.id,
            trackId: 1,
            offset: clipSpec.offset,
            timeView: TimeViewModel(
              start: clipSpec.sourceStart,
              end: clipSpec.sourceEnd ?? clipSpec.sourceStart + clipSpec.width,
            ),
          );
        })
        .toList(growable: false);

    return buildAutomationHoldSegments(project: project, clips: clips);
  } finally {
    project.dispose();
  }
}

double _evaluatePoints(List<_PointSpec> pointSpecs, double tick) {
  final project = ProjectModel.create();
  try {
    final points = _createAutomationPoints(project, pointSpecs);
    return evaluateAutomationHoldValueAtSourceTick(points, tick);
  } finally {
    project.dispose();
  }
}

_ClipSpec _clip({
  required Id id,
  required int offset,
  required int width,
  int sourceStart = 0,
  int? sourceEnd,
  List<_PointSpec> points = const [],
}) {
  return (
    id: id,
    offset: offset,
    width: width,
    sourceStart: sourceStart,
    sourceEnd: sourceEnd,
    points: points,
  );
}

_PointSpec _point(
  int offset,
  double value, {
  AutomationCurveType curve = AutomationCurveType.smooth,
}) {
  return (offset: offset, value: value, curve: curve);
}

void _expectSegment(
  AutomationHoldSegment segment, {
  required double start,
  required double end,
  required double value,
}) {
  expect(segment.startTick, closeTo(start, 1e-9));
  if (end.isInfinite) {
    expect(segment.endTick, end);
  } else {
    expect(segment.endTick, closeTo(end, 1e-9));
  }
  expect(segment.value, closeTo(value, 1e-9));
}

class _AutomationHoldPaintFixture {
  final ProjectModel project;
  final TrackModel lane;

  _AutomationHoldPaintFixture._({required this.project, required this.lane});

  factory _AutomationHoldPaintFixture.create({
    bool withAutomationClips = true,
  }) {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);

    final parentTrack = project.tracks[project.trackOrder.first]!;
    final utilityNode = parentTrack.requireProcessing.utilityNode!;
    final balancePort = utilityNode.getPortById(
      UtilityProcessorModel.balancePortId,
    );
    balancePort.parameterValue = 0.35;
    final viewModel = ServiceRegistry.forProject(project.id).arrangerViewModel;

    AutomationLaneAddRemoveCommand.add(
      project: project,
      parentTrackId: parentTrack.id,
      nodeId: utilityNode.id,
      portId: UtilityProcessorModel.balancePortId,
      name: 'Balance',
    ).execute(project);

    final lane = project.tracks[parentTrack.automationLanes.single]!;
    viewModel.automationExpandedByTrackId[parentTrack.id] = true;

    if (!withAutomationClips) {
      return _AutomationHoldPaintFixture._(project: project, lane: lane);
    }

    final firstPattern = _addPattern(project, 'A', [
      _point(0, 0.2),
      _point(96, 0.75),
    ]);
    final emptyPattern = _addPattern(project, 'Empty', const []);
    final secondPattern = _addPattern(project, 'B', [
      _point(0, 0.4),
      _point(96, 0.1),
    ]);

    final arrangement = project.sequence.arrangement;
    _addClip(
      project: project,
      arrangement: arrangement,
      patternId: firstPattern.id,
      trackId: lane.id,
      offset: 0,
      start: 0,
      end: 96,
    );
    _addClip(
      project: project,
      arrangement: arrangement,
      patternId: emptyPattern.id,
      trackId: lane.id,
      offset: 144,
      start: 0,
      end: 48,
    );
    _addClip(
      project: project,
      arrangement: arrangement,
      patternId: secondPattern.id,
      trackId: lane.id,
      offset: 288,
      start: 0,
      end: 96,
    );

    return _AutomationHoldPaintFixture._(project: project, lane: lane);
  }

  ArrangementModel get arrangement => project.sequence.arrangement;

  ArrangerViewModel get viewModel =>
      ServiceRegistry.forProject(project.id).arrangerViewModel;

  void dispose() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  }
}

PatternModel _addPattern(
  ProjectModel project,
  String name,
  List<_PointSpec> points,
) {
  final pattern = PatternModel(idAllocator: project.idAllocator, name: name);

  pattern.automation.points.addAll(_createAutomationPoints(project, points));

  project.sequence.patterns[pattern.id] = pattern;
  return pattern;
}

List<AutomationPointModel> _createAutomationPoints(
  ProjectModel project,
  List<_PointSpec> points,
) {
  return points
      .map(
        (point) => AutomationPointModel(
          idAllocator: project.idAllocator,
          offset: point.offset,
          value: point.value,
          curve: point.curve,
        ),
      )
      .toList(growable: false);
}

void _addClip({
  required ProjectModel project,
  required ArrangementModel arrangement,
  required Id patternId,
  required Id trackId,
  required int offset,
  required int start,
  required int end,
}) {
  final clip = ClipModel(
    idAllocator: project.idAllocator,
    patternId: patternId,
    trackId: trackId,
    offset: offset,
    timeView: TimeViewModel(start: start, end: end),
  );

  arrangement.clips[clip.id] = clip;
}

Future<int> _countNonTransparentPixels(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  if (byteData == null) {
    throw StateError('Failed to read image bytes.');
  }

  final bytes = byteData.buffer.asUint8List();
  var pixelCount = 0;

  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] > 0) {
      pixelCount++;
    }
  }

  return pixelCount;
}
