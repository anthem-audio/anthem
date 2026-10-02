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

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'waits.dart';

/// Failure evidence is best effort, bounded, and collected before app cleanup.
/// Collector errors are recorded alongside the original error, never rethrown.
class FailureArtifacts {
  final WidgetTester tester;
  final Directory directory;

  FailureArtifacts(this.tester, this.directory);

  Future<void> capture({
    required Object error,
    required StackTrace stack,
    required Object? Function() collectSession,
    required Object? Function() collectProject,
    required Object? Function() collectUi,
    required Map<String, Object? Function()> additionalDiagnostics,
    required Future<String> Function() queryEngine,
    required Future<Uint8List?> Function() captureScreenshot,
  }) async {
    final report = <String, Object?>{
      'test': tester.testDescription,
      'error': error.toString(),
      'stackTrace': stack.toString(),
      'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    void collect(String name, Object? Function() action) {
      try {
        report[name] = action();
      } catch (error, stack) {
        report[name] = {
          'error': error.toString(),
          'stackTrace': stack.toString(),
        };
      }
    }

    Future<void> collectAsync(
      String name,
      Future<Object?> Function() action, {
      Duration timeout = const Duration(seconds: 3),
    }) async {
      try {
        report[name] = await waitForFuture(
          tester,
          Future.sync(action),
          conditionDescription: 'failure artifact $name',
          collectTimeoutDiagnostics: () => report['session'],
          timeout: timeout,
          checkFrameworkErrors: false,
        );
      } catch (error, stack) {
        report[name] = {
          'error': error.toString(),
          'stackTrace': stack.toString(),
        };
      }
    }

    collect('session', collectSession);
    collect('project', collectProject);
    collect('ui', collectUi);
    for (final entry in additionalDiagnostics.entries) {
      collect(entry.key, entry.value);
    }
    await collectAsync('screenshot', () async {
      final bytes = await captureScreenshot();
      if (bytes == null) {
        return {'status': 'unavailable', 'reason': 'No mounted Flutter frame.'};
      }
      await directory.create(recursive: true);
      await File('${directory.path}/failure.png')
          .writeAsBytes(bytes, flush: true);
      return {
        'status': 'saved',
        'path': 'failure.png',
        'scope': 'Flutter surface only',
      };
    }, timeout: const Duration(seconds: 10));
    await collectAsync(
      'engineModel',
      () async => jsonDecode(await queryEngine()),
    );
    // A filesystem failure must not replace the scenario's original failure.
    try {
      await waitForFuture(
        tester,
        () async {
          await directory.create(recursive: true);
          await File('${directory.path}/failure.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(report),
            flush: true,
          );
        }(),
        conditionDescription: 'write failure report',
        collectTimeoutDiagnostics: () => report['session'],
        timeout: const Duration(seconds: 3),
        checkFrameworkErrors: false,
      );
    } catch (artifactError) {
      debugPrint(
        'Could not save failure artifacts: $artifactError. Original failure: $error',
      );
    }
  }
}
