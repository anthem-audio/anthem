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

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../bin/integration_test/verify_failure_artifacts.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'anthem-failure-verifier-',
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff223344), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1280, 800);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    var childPid = 100;
    for (final entry in {
      'assertion-probe': 'Intentional assertion probe',
      'framework-probe': 'Intentional framework probe',
      'unawaited-probe': 'Intentional unawaited probe',
      'unresponsive-engine-probe': 'Intentional unresponsive engine probe',
      'startup-failure-probe': 'Engine startup failed',
    }.entries) {
      final early = entry.key == 'startup-failure-probe';
      final pid = early ? null : childPid++;
      final root = Directory('${directory.path}/${entry.key}');
      await root.create();
      await File('${root.path}/failure.json').writeAsString(
        jsonEncode({
          'error': entry.value,
          'session': {'runId': 'current-run', 'enginePid': pid},
          'project': {
            'id': 'fixture-project',
            'trackOrder': [17],
            'sequence': {'beatsPerMinuteRaw': 13700},
          },
          'ui': {
            'selectedNotes': [42],
            'heldPointerCount': 1,
            'heldKeys': ['Shift Left'],
          },
          'screenshot': {
            'status': early ? 'unavailable' : 'saved',
            'reason': early ? 'No mounted Flutter frame.' : null,
          },
          'engineModel': entry.key == 'unresponsive-engine-probe' || early
              ? {'error': 'Request timed out'}
              : {
                  'tracks': <String, Object?>{},
                  'trackOrder': [17],
                  'sequence': {'beatsPerMinuteRaw': 13700},
                },
          'pianoRoll': {
            'targetTimeRange': [0, 384],
            'renderedTimeRange': [0, 384],
            'canvasBounds': 'Rect(0, 0, 800, 400)',
          },
          'brokenCollector': {'error': 'Intentional collector failure'},
        }),
      );
      await File('${root.path}/stopped.json').writeAsString(
        jsonEncode({
          'runId': 'current-run',
          'enginePid': pid,
          'engineState': 'stopped',
          'cleanupError': null,
          'engineExitCode': early ? null : -15,
        }),
      );
      if (!early) {
        await File('${root.path}/failure.png')
            .writeAsBytes(png!.buffer.asUint8List());
      }
    }
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<void> verify({int exitCode = 1, String runId = 'current-run'}) =>
      verifyFailureArtifacts(directory, testExitCode: exitCode, runId: runId);
  Future<void> change(
    String caseName,
    String fileName,
    void Function(Map<String, dynamic>) edit,
  ) async {
    final file = File('${directory.path}/$caseName/$fileName.json');
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    edit(data);
    await file.writeAsString(jsonEncode(data));
  }

  test('accepts evidence from all failures including an unavailable engine and frame', () async {
    await verify();
    final result = jsonDecode(
      await File('${directory.path}/verification.json').readAsString(),
    ) as Map;
    expect(result['status'], 'passed');
    expect(result['verified'], hasLength(5));
  });
  test('rejects a probe process that passed', () async {
    await expectLater(verify(exitCode: 0), throwsStateError);
  });
  test(
    'verifies Windows cases without the unsupported suspension probe',
    () async {
      await Directory('${directory.path}/unresponsive-engine-probe')
          .delete(recursive: true);
      await verifyFailureArtifacts(
        directory,
        testExitCode: 1,
        runId: 'current-run',
        includeUnresponsiveEngine: false,
      );
      final result = jsonDecode(
        await File('${directory.path}/verification.json').readAsString(),
      ) as Map;
      expect(result['verified'], hasLength(4));
      expect(result['verified'], isNot(contains('unresponsive-engine-probe')));
    },
  );
  test('rejects stale artifacts after a compile or launch failure', () async {
    await expectLater(verify(runId: 'new-run'), throwsStateError);
  });
  test('rejects missing failure evidence', () async {
    await File('${directory.path}/framework-probe/failure.json').delete();
    await expectLater(verify(), throwsA(isA<FileSystemException>()));
  });
  test(
    'rejects a diagnostic error that replaced the original assertion',
    () async {
      await change(
        'assertion-probe',
        'failure',
        (data) => data['error'] = 'Intentional collector failure',
      );
      await expectLater(verify(), throwsStateError);
    },
  );
  test('rejects cleanup without an actual child exit', () async {
    await change(
      'framework-probe',
      'stopped',
      (data) => data['engineExitCode'] = null,
    );
    await expectLater(verify(), throwsStateError);
  });
  test('rejects a forced or otherwise failed shutdown', () async {
    await change(
      'framework-probe',
      'stopped',
      (data) => data['cleanupError'] = 'forced shutdown',
    );
    await expectLater(verify(), throwsStateError);
  });
  test(
    'rejects an engine snapshot with different synchronized content',
    () async {
      await change(
        'framework-probe',
        'failure',
        (data) => data['engineModel'] = {
          'tracks': <String, Object?>{},
          'trackOrder': [17],
          'sequence': {'beatsPerMinuteRaw': 12000},
        },
      );
      await expectLater(verify(), throwsStateError);
    },
  );
  test('rejects a corrupt screenshot', () async {
    await File('${directory.path}/assertion-probe/failure.png')
        .writeAsBytes([1, 2, 3]);
    await expectLater(verify(), throwsStateError);
  });
}
