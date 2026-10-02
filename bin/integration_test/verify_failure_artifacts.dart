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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A failed probe process alone is insufficient: a compile or launch failure
/// must not be mistaken for successful verification of failure reporting.
Future<void> verifyFailureArtifacts(
  Directory directory, {
  required int testExitCode,
  required String runId,
  bool includeUnresponsiveEngine = true,
}) async {
  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  require(testExitCode != 0, 'Intentional probes unexpectedly passed.');
  final cases = {
    'assertion-probe': 'Intentional assertion probe',
    'framework-probe': 'Intentional framework probe',
    'unawaited-probe': 'Intentional unawaited probe',
    if (includeUnresponsiveEngine)
      'unresponsive-engine-probe': 'Intentional unresponsive engine probe',
    'startup-failure-probe': 'Engine startup failed',
  };
  final verified = <String>[];
  for (final entry in cases.entries) {
    final root = Directory('${directory.path}/${entry.key}');
    final report = jsonDecode(
      await File('${root.path}/failure.json').readAsString(),
    ) as Map;
    require(
      (report['error'] as String).contains(entry.value),
      '${entry.key}: original failure was not retained.',
    );
    require(
      report['project'] is Map &&
          report['ui'] is Map &&
          report['session'] is Map,
      '${entry.key}: missing state snapshots.',
    );
    final session = report['session'] as Map;
    final stopped = jsonDecode(
      await File('${root.path}/stopped.json').readAsString(),
    ) as Map;
    require(
      session['runId'] == runId && stopped['runId'] == runId,
      '${entry.key}: artifacts belong to another run.',
    );
    require(
      stopped['engineState'] == 'stopped',
      '${entry.key}: engine was not stopped.',
    );
    require(
      stopped.containsKey('cleanupError') && stopped['cleanupError'] == null,
      '${entry.key}: session cleanup failed.',
    );
    require(
      stopped['enginePid'] == session['enginePid'],
      '${entry.key}: shutdown is for a different engine.',
    );
    final screenshot = report['screenshot'] as Map;
    if (entry.key == 'startup-failure-probe') {
      require(
        screenshot['status'] == 'unavailable' && screenshot['reason'] != null,
        'Startup probe must explain why no frame exists.',
      );
      require(
        session['enginePid'] == null,
        'Missing executable unexpectedly started a child.',
      );
    } else {
      require(
        stopped['enginePid'] != null && stopped['engineExitCode'] != null,
        '${entry.key}: no actual child exit was recorded.',
      );
      require(
        screenshot['status'] == 'saved',
        '${entry.key}: screenshot capture failed.',
      );
      final bytes = await File('${root.path}/failure.png').readAsBytes();
      const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
      require(
        bytes.length > 24 &&
            List.generate(
              8,
              (i) => bytes[i] == pngSignature[i],
            ).every((same) => same),
        '${entry.key}: invalid PNG.',
      );
      final dimensions = ByteData.sublistView(bytes, 16, 24);
      require(
        dimensions.getUint32(0) == 1280 && dimensions.getUint32(4) == 800,
        '${entry.key}: screenshot does not cover the Flutter surface.',
      );
      if (entry.key == 'unresponsive-engine-probe') {
        require(
          ((report['engineModel'] as Map)['error'] as String).contains(
            'timed out',
          ),
          'Unresponsive engine must record a bounded query failure.',
        );
      } else {
        // Project IDs are Dart-only (@hideFromCpp). Compare representative
        // synchronized content; session metadata identifies the queried engine.
        final engine = report['engineModel'] as Map;
        final project = report['project'] as Map;
        require(
          engine['tracks'] is Map &&
              jsonEncode(engine['trackOrder']) ==
                  jsonEncode(project['trackOrder']) &&
              (engine['sequence'] as Map)['beatsPerMinuteRaw'] ==
                  (project['sequence'] as Map)['beatsPerMinuteRaw'],
          '${entry.key}: engine snapshot does not match synchronized content.',
        );
      }
    }
    if (entry.key == 'assertion-probe') {
      final ui = report['ui'] as Map;
      require(
        (ui['selectedNotes'] as List).isNotEmpty &&
            ui['heldPointerCount'] == 1 &&
            (ui['heldKeys'] as List).isNotEmpty,
        'Assertion probe lost selection or held input before capture.',
      );
      final viewport = report['pianoRoll'] as Map;
      require(
        viewport['targetTimeRange'] != null &&
            viewport['renderedTimeRange'] != null &&
            viewport['canvasBounds'] != null,
        'Assertion probe lost viewport details.',
      );
      require(
        (report['brokenCollector'] as Map)['error'] != null,
        'Broken diagnostic collector did not record its error.',
      );
    }
    verified.add(entry.key);
  }
  await File('${directory.path}/verification.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'status': 'passed',
      'runId': runId,
      'probeExitCode': testExitCode,
      'verified': verified,
    }),
    flush: true,
  );
}
