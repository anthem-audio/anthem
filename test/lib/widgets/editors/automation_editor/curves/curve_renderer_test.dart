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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';
import 'package:anthem_codegen/include/collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetCurrentCurveCacheForTesting();
  });

  group('CoordinateBuffer', () {
    test('grows when capacity is exceeded and clear resets logical length', () {
      final buffer = CoordinateBuffer();

      for (var i = 0; i < 300; i++) {
        buffer.add(i.toDouble(), (i * 2).toDouble());
      }

      expect(buffer.coordinateCount, equals(300));
      expect(buffer.bufferRaw.length, greaterThan(512));
      expect(buffer.buffer.length, equals(600));
      expect(buffer.buffer[0], equals(0.0));
      expect(buffer.buffer[1], equals(0.0));
      expect(buffer.buffer[598], equals(299.0));
      expect(buffer.buffer[599], equals(598.0));

      buffer.clear();

      expect(buffer.coordinateCount, equals(0));
      expect(buffer.buffer.length, equals(0));
      expect(buffer.bufferRaw.length, greaterThan(512));
    });
  });

  group('LineBuffer', () {
    test('add, clear, and disconnect behavior', () {
      final buffer = LineBuffer();

      expect(buffer.add(0, 0), isNull);
      final firstLine = buffer.add(10, 10);
      expect(firstLine, isNotNull);
      expect(firstLine!.$1, equals(0.0));
      expect(firstLine.$2, equals(0.0));
      expect(firstLine.$3, equals(10.0));
      expect(firstLine.$4, equals(10.0));
      expect(buffer.lineCount, equals(1));

      buffer.disconnectNext();
      expect(buffer.add(20, 20), isNull);
      expect(buffer.lineCount, equals(1));

      final secondLine = buffer.add(30, 30);
      expect(secondLine, isNotNull);
      expect(secondLine!.$1, equals(20.0));
      expect(secondLine.$2, equals(20.0));
      expect(secondLine.$3, equals(30.0));
      expect(secondLine.$4, equals(30.0));
      expect(buffer.lineCount, equals(2));

      buffer.clear();
      expect(buffer.lineCount, equals(0));
      expect(buffer.buffer.length, equals(0));
    });

    test('grows when capacity is exceeded', () {
      final buffer = LineBuffer();

      for (var i = 0; i < 150; i++) {
        buffer.add(i.toDouble(), i.toDouble());
      }

      expect(buffer.lineCount, equals(149));
      expect(buffer.bufferRaw.length, greaterThan(512));
    });
  });

  group('evaluateCurveForTesting', () {
    test(
      'returns first value before first point and last value past last point',
      () {
        final points = <AutomationPoint>[
          (
            offset: 0.0,
            value: 0.2,
            tension: 0.0,
            curve: AutomationCurveType.smooth,
          ),
          (
            offset: 10.0,
            value: 0.8,
            tension: 0.0,
            curve: AutomationCurveType.smooth,
          ),
        ];

        expect(evaluateCurveForTesting(-5.0, points), closeTo(0.2, 1e-12));
        expect(evaluateCurveForTesting(50.0, points), closeTo(0.8, 1e-12));
      },
    );

    test('hold curve keeps the first value of its segment', () {
      final points = <AutomationPoint>[
        (
          offset: 0.0,
          value: 0.1,
          tension: 0.0,
          curve: AutomationCurveType.smooth,
        ),
        (
          offset: 10.0,
          value: 0.9,
          tension: 0.0,
          curve: AutomationCurveType.hold,
        ),
      ];

      expect(evaluateCurveForTesting(0.0, points), closeTo(0.1, 1e-12));
      expect(evaluateCurveForTesting(5.0, points), closeTo(0.1, 1e-12));
      expect(evaluateCurveForTesting(9.9, points), closeTo(0.1, 1e-12));
    });

    test('smooth segment respects endpoints and remains within range', () {
      final points = <AutomationPoint>[
        (
          offset: 0.0,
          value: 0.25,
          tension: 0.0,
          curve: AutomationCurveType.smooth,
        ),
        (
          offset: 10.0,
          value: 0.75,
          tension: 0.0,
          curve: AutomationCurveType.smooth,
        ),
      ];

      expect(evaluateCurveForTesting(0.0, points), closeTo(0.25, 1e-12));
      expect(evaluateCurveForTesting(10.0, points), closeTo(0.75, 1e-12));

      final mid = evaluateCurveForTesting(5.0, points);
      expect(mid, greaterThanOrEqualTo(0.25));
      expect(mid, lessThanOrEqualTo(0.75));
    });

    test('stairs and wave curve types currently throw unimplemented', () {
      final basePoints = <AutomationPoint>[
        (
          offset: 0.0,
          value: 0.2,
          tension: 0.0,
          curve: AutomationCurveType.smooth,
        ),
      ];

      final stairsPoints = [
        ...basePoints,
        (
          offset: 10.0,
          value: 0.8,
          tension: 0.0,
          curve: AutomationCurveType.stairs,
        ),
      ];

      final wavePoints = [
        ...basePoints,
        (
          offset: 10.0,
          value: 0.8,
          tension: 0.0,
          curve: AutomationCurveType.wave,
        ),
      ];

      expect(
        () => evaluateCurveForTesting(5.0, stairsPoints),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => evaluateCurveForTesting(5.0, wavePoints),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test(
      'updates and reuses segment cache for monotonic and non-monotonic time',
      () {
        final points = <AutomationPoint>[
          (
            offset: 0.0,
            value: 0.1,
            tension: 0.0,
            curve: AutomationCurveType.smooth,
          ),
          (
            offset: 10.0,
            value: 0.2,
            tension: 0.0,
            curve: AutomationCurveType.hold,
          ),
          (
            offset: 20.0,
            value: 0.4,
            tension: 0.0,
            curve: AutomationCurveType.hold,
          ),
          (
            offset: 30.0,
            value: 0.8,
            tension: 0.0,
            curve: AutomationCurveType.hold,
          ),
        ];

        expect(evaluateCurveForTesting(1.0, points), closeTo(0.1, 1e-12));
        expect(currentCurveCacheForTesting, equals((0, 1)));

        expect(evaluateCurveForTesting(15.0, points), closeTo(0.2, 1e-12));
        expect(currentCurveCacheForTesting, equals((1, 2)));

        expect(evaluateCurveForTesting(25.0, points), closeTo(0.4, 1e-12));
        expect(currentCurveCacheForTesting, equals((2, 3)));

        expect(evaluateCurveForTesting(5.0, points), closeTo(0.1, 1e-12));
        expect(currentCurveCacheForTesting, equals((0, 1)));
      },
    );
  });

  group('DownsamplingCurveBuilder', () {
    test('collapses nearly straight points into fewer segments', () {
      final lineBuffer = LineBuffer();
      final lineJoinBuffer = CoordinateBuffer();
      final triCoordBuffer = CoordinateBuffer();

      final builder = DownsamplingCurveBuilder(
        lineBuffer: lineBuffer,
        lineJoinBuffer: lineJoinBuffer,
        triCoordBuffer: triCoordBuffer,
        baseY: 100.0,
      );

      builder.addPoint(0.0, 50.0);
      builder.addPoint(10.0, 50.0);
      builder.addPoint(20.0, 50.0);
      builder.finish();

      expect(lineBuffer.lineCount, equals(1));
      expect(lineJoinBuffer.coordinateCount, equals(0));
      expect(triCoordBuffer.coordinateCount, equals(6));
    });

    test('adds a line join point for sharp turns', () {
      final lineBuffer = LineBuffer();
      final lineJoinBuffer = CoordinateBuffer();
      final triCoordBuffer = CoordinateBuffer();

      final builder = DownsamplingCurveBuilder(
        lineBuffer: lineBuffer,
        lineJoinBuffer: lineJoinBuffer,
        triCoordBuffer: triCoordBuffer,
        baseY: 100.0,
      );

      builder.addPoint(0.0, 50.0);
      builder.addPoint(10.0, 50.0);
      builder.addPoint(10.0, 10.0);
      builder.finish();

      expect(lineBuffer.lineCount, equals(2));
      expect(lineJoinBuffer.coordinateCount, equals(1));
      expect(triCoordBuffer.coordinateCount, equals(12));

      final lineJoinPoints = lineJoinBuffer.buffer;
      expect(lineJoinPoints[0], closeTo(10.0, 1e-6));
      expect(lineJoinPoints[1], closeTo(50.0, 1e-6));
    });

    test(
      'keeps handle join but de-duplicates near-handle follow-up sample',
      () {
        final lineBuffer = LineBuffer();
        final lineJoinBuffer = CoordinateBuffer();
        final triCoordBuffer = CoordinateBuffer();

        final builder = DownsamplingCurveBuilder(
          lineBuffer: lineBuffer,
          lineJoinBuffer: lineJoinBuffer,
          triCoordBuffer: triCoordBuffer,
          baseY: 100.0,
        );

        builder.addPoint(0.0, 0.0);
        builder.addPoint(0.4, 0.0);
        builder.addPoint(0.8, 0.0, true);
        builder.addPoint(0.9, 0.0);
        builder.finish();

        expect(lineJoinBuffer.coordinateCount, equals(1));
        expect(lineBuffer.lineCount, equals(1));
      },
    );
  });

  group('renderAutomationCurve', () {
    test('returns immediately with fewer than two points', () {
      final points = _makePointModelList([
        (offset: 0, value: 0.5, curve: AutomationCurveType.smooth),
      ]);

      final lineBuffer = LineBuffer();
      lineBuffer.add(0.0, 0.0);
      lineBuffer.add(1.0, 1.0);
      final lineJoinBuffer = CoordinateBuffer();
      lineJoinBuffer.add(1.0, 1.0);
      final triCoordBuffer = CoordinateBuffer();
      triCoordBuffer.add(1.0, 1.0);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      renderAutomationCurve(
        canvas: canvas,
        canvasSize: const ui.Size(100, 40),
        xDrawPositionTime: (0.0, 100.0),
        yDrawPositionPixels: (0.0, 40.0),
        points: points,
        strokeWidth: 2.0,
        timeViewStart: 0.0,
        timeViewEnd: 100.0,
        lineBuffer: lineBuffer,
        lineJoinBuffer: lineJoinBuffer,
        triCoordBuffer: triCoordBuffer,
      );

      expect(lineBuffer.lineCount, equals(1));
      expect(lineJoinBuffer.coordinateCount, equals(1));
      expect(triCoordBuffer.coordinateCount, equals(1));
      expect(points.observationBlockDepth, equals(0));
    });

    test(
      'fills provided buffers and does not clear them when all are provided',
      () {
        final points = _makePointModelList([
          (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
          (offset: 50, value: 0.8, curve: AutomationCurveType.smooth),
        ]);

        final lineBuffer = LineBuffer();
        final lineJoinBuffer = CoordinateBuffer();
        final triCoordBuffer = CoordinateBuffer();

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        renderAutomationCurve(
          canvas: canvas,
          canvasSize: const ui.Size(100, 40),
          xDrawPositionTime: (0.0, 100.0),
          yDrawPositionPixels: (0.0, 40.0),
          points: points,
          strokeWidth: 2.0,
          timeViewStart: 0.0,
          timeViewEnd: 100.0,
          lineBuffer: lineBuffer,
          lineJoinBuffer: lineJoinBuffer,
          triCoordBuffer: triCoordBuffer,
        );

        expect(lineBuffer.lineCount, greaterThan(0));
        expect(triCoordBuffer.coordinateCount, greaterThan(0));
        expect(points.observationBlockDepth, equals(0));
      },
    );

    test('clips sampled x positions to viewport boundaries', () {
      final points = _makePointModelList([
        (offset: -50, value: 0.2, curve: AutomationCurveType.smooth),
        (offset: 200, value: 0.9, curve: AutomationCurveType.smooth),
      ]);

      final lineBuffer = LineBuffer();
      final lineJoinBuffer = CoordinateBuffer();
      final triCoordBuffer = CoordinateBuffer();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      renderAutomationCurve(
        canvas: canvas,
        canvasSize: const ui.Size(100, 40),
        xDrawPositionTime: (0.0, 100.0),
        yDrawPositionPixels: (0.0, 40.0),
        points: points,
        strokeWidth: 2.0,
        timeViewStart: 0.0,
        timeViewEnd: 100.0,
        lineBuffer: lineBuffer,
        lineJoinBuffer: lineJoinBuffer,
        triCoordBuffer: triCoordBuffer,
      );

      _expectLineBufferXWithin(lineBuffer, minX: 0.0, maxX: 100.0);
    });

    test(
      'applies clipStart clipEnd and clipOffset bounds to sampling window',
      () {
        final points = _makePointModelList([
          (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
          (offset: 200, value: 0.8, curve: AutomationCurveType.smooth),
        ]);

        final lineBuffer = LineBuffer();
        final lineJoinBuffer = CoordinateBuffer();
        final triCoordBuffer = CoordinateBuffer();

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        renderAutomationCurve(
          canvas: canvas,
          canvasSize: const ui.Size(100, 40),
          xDrawPositionTime: (0.0, 100.0),
          yDrawPositionPixels: (0.0, 40.0),
          points: points,
          strokeWidth: 2.0,
          timeViewStart: 0.0,
          timeViewEnd: 100.0,
          clipStart: 50.0,
          clipEnd: 120.0,
          clipOffset: 10.0,
          lineBuffer: lineBuffer,
          lineJoinBuffer: lineJoinBuffer,
          triCoordBuffer: triCoordBuffer,
        );

        _expectLineBufferXWithin(lineBuffer, minX: 10.0, maxX: 80.0);
      },
    );

    test(
      'adds join points for internal handles when crossing curve segments',
      () {
        final points = _makePointModelList([
          (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
          (offset: 30, value: 0.7, curve: AutomationCurveType.smooth),
          (offset: 60, value: 0.4, curve: AutomationCurveType.smooth),
          (offset: 90, value: 0.8, curve: AutomationCurveType.smooth),
        ]);

        final lineBuffer = LineBuffer();
        final lineJoinBuffer = CoordinateBuffer();
        final triCoordBuffer = CoordinateBuffer();

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        renderAutomationCurve(
          canvas: canvas,
          canvasSize: const ui.Size(100, 40),
          xDrawPositionTime: (0.0, 100.0),
          yDrawPositionPixels: (0.0, 40.0),
          points: points,
          strokeWidth: 2.0,
          timeViewStart: 0.0,
          timeViewEnd: 100.0,
          lineBuffer: lineBuffer,
          lineJoinBuffer: lineJoinBuffer,
          triCoordBuffer: triCoordBuffer,
        );

        _expectCoordinateInBuffer(
          lineJoinBuffer,
          x: 30.0,
          y: 40.0 * (1.0 - 0.7),
          tolerance: 1e-4,
        );
        _expectCoordinateInBuffer(
          lineJoinBuffer,
          x: 60.0,
          y: 40.0 * (1.0 - 0.4),
          tolerance: 1e-4,
        );

        for (var i = 0; i < lineJoinBuffer.buffer.length; i += 2) {
          final x = lineJoinBuffer.buffer[i];
          expect(x, greaterThanOrEqualTo(0.0 - 1e-6));
          expect(x, lessThanOrEqualTo(100.0 + 1e-6));
        }
      },
    );

    test('correctForClipBounds shifts start sample by one pixel', () {
      final points = _makePointModelList([
        (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
        (offset: 200, value: 0.8, curve: AutomationCurveType.smooth),
      ]);

      final withoutCorrection = (
        lineBuffer: LineBuffer(),
        lineJoinBuffer: CoordinateBuffer(),
        triCoordBuffer: CoordinateBuffer(),
      );
      final withCorrection = (
        lineBuffer: LineBuffer(),
        lineJoinBuffer: CoordinateBuffer(),
        triCoordBuffer: CoordinateBuffer(),
      );

      final recorderA = ui.PictureRecorder();
      final canvasA = ui.Canvas(recorderA);
      renderAutomationCurve(
        canvas: canvasA,
        canvasSize: const ui.Size(100, 40),
        xDrawPositionTime: (0.0, 100.0),
        yDrawPositionPixels: (0.0, 40.0),
        points: points,
        strokeWidth: 2.0,
        timeViewStart: 0.0,
        timeViewEnd: 100.0,
        clipStart: 50.0,
        clipEnd: 120.0,
        clipOffset: 10.0,
        lineBuffer: withoutCorrection.lineBuffer,
        lineJoinBuffer: withoutCorrection.lineJoinBuffer,
        triCoordBuffer: withoutCorrection.triCoordBuffer,
        correctForClipBounds: false,
      );

      final recorderB = ui.PictureRecorder();
      final canvasB = ui.Canvas(recorderB);
      renderAutomationCurve(
        canvas: canvasB,
        canvasSize: const ui.Size(100, 40),
        xDrawPositionTime: (0.0, 100.0),
        yDrawPositionPixels: (0.0, 40.0),
        points: points,
        strokeWidth: 2.0,
        timeViewStart: 0.0,
        timeViewEnd: 100.0,
        clipStart: 50.0,
        clipEnd: 120.0,
        clipOffset: 10.0,
        lineBuffer: withCorrection.lineBuffer,
        lineJoinBuffer: withCorrection.lineJoinBuffer,
        triCoordBuffer: withCorrection.triCoordBuffer,
        correctForClipBounds: true,
      );

      final firstXWithoutCorrection = withoutCorrection.lineBuffer.buffer[0];
      final firstXWithCorrection = withCorrection.lineBuffer.buffer[0];

      expect(
        firstXWithCorrection - firstXWithoutCorrection,
        closeTo(1.0, 1e-6),
      );
    });

    test(
      'paint path clears provided line buffer when all buffers are not provided',
      () {
        final points = _makePointModelList([
          (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
          (offset: 100, value: 0.8, curve: AutomationCurveType.smooth),
        ]);

        final lineBuffer = LineBuffer();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        renderAutomationCurve(
          canvas: canvas,
          canvasSize: const ui.Size(100, 40),
          xDrawPositionTime: (0.0, 100.0),
          yDrawPositionPixels: (0.0, 40.0),
          points: points,
          strokeWidth: 2.0,
          timeViewStart: 0.0,
          timeViewEnd: 100.0,
          lineBuffer: lineBuffer,
        );

        expect(lineBuffer.lineCount, equals(0));
      },
    );

    test('paint path produces visible pixels', () async {
      final points = _makePointModelList([
        (offset: 0, value: 0.2, curve: AutomationCurveType.smooth),
        (offset: 100, value: 0.8, curve: AutomationCurveType.smooth),
      ]);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      renderAutomationCurve(
        canvas: canvas,
        canvasSize: const ui.Size(100, 40),
        xDrawPositionTime: (0.0, 100.0),
        yDrawPositionPixels: (0.0, 40.0),
        points: points,
        strokeWidth: 2.0,
        timeViewStart: 0.0,
        timeViewEnd: 100.0,
      );

      final image = await recorder.endRecording().toImage(100, 40);
      final nonTransparentPixelCount = await _countNonTransparentPixels(image);
      image.dispose();

      expect(nonTransparentPixelCount, greaterThan(0));
    });
  });
}

AnthemObservableList<AutomationPointModel> _makePointModelList(
  List<({int offset, double value, AutomationCurveType curve})> points,
) {
  return AnthemObservableList.of(
    points
        .map(
          (point) => AutomationPointModel(
            idAllocator: ProjectEntityIdAllocator.test(getId),
            offset: point.offset,
            value: point.value,
            tension: 0.0,
            curve: point.curve,
          ),
        )
        .toList(),
  );
}

void _expectLineBufferXWithin(
  LineBuffer lineBuffer, {
  required double minX,
  required double maxX,
}) {
  expect(lineBuffer.lineCount, greaterThan(0));

  final values = lineBuffer.buffer;

  for (var i = 0; i < values.length; i += 4) {
    final x1 = values[i];
    final x2 = values[i + 2];

    expect(x1, greaterThanOrEqualTo(minX - 1e-6));
    expect(x1, lessThanOrEqualTo(maxX + 1e-6));
    expect(x2, greaterThanOrEqualTo(minX - 1e-6));
    expect(x2, lessThanOrEqualTo(maxX + 1e-6));
  }
}

void _expectCoordinateInBuffer(
  CoordinateBuffer buffer, {
  required double x,
  required double y,
  required double tolerance,
}) {
  bool found = false;

  for (var i = 0; i < buffer.buffer.length; i += 2) {
    final actualX = buffer.buffer[i];
    final actualY = buffer.buffer[i + 1];

    if ((actualX - x).abs() <= tolerance && (actualY - y).abs() <= tolerance) {
      found = true;
      break;
    }
  }

  expect(found, isTrue, reason: 'Expected coordinate ($x, $y) was not found.');
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
      pixelCount += 1;
    }
  }

  return pixelCount;
}
