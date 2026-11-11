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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Pumps frames while allowing real timers, plugin calls and IPC to progress.
/// Never waits for global idleness: meters and animations can keep scheduling
/// frames indefinitely. Exceptions retain their original stack traces.
///
/// [conditionDescription] labels the wait in timeout messages.
/// [collectTimeoutDiagnostics] is called only on timeout to describe the current
/// state for debugging. It does not determine readiness or record a history.
Future<void> waitUntil(
  WidgetTester tester, {
  required String conditionDescription,
  required bool Function() isReady,
  required Object? Function() collectTimeoutDiagnostics,
  Duration timeout = const Duration(seconds: 15),
  void Function()? checkHealth,
  bool checkFrameworkErrors = true,
}) async {
  final clock = Stopwatch()..start();
  while (true) {
    if (checkFrameworkErrors) {
      final exception = tester.takeException();
      if (exception != null) throw exception;
    }
    checkHealth?.call();
    if (isReady()) return;
    if (clock.elapsed >= timeout) {
      throw TimeoutException(
        'Waiting for $conditionDescription. '
        'Timeout diagnostics: ${collectTimeoutDiagnostics()}',
        timeout,
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A deadline on one operation, with the same frame/IPC progress as waitUntil.
/// The future's completion is handled even after timeout so a late failure
/// isn't unhandled. [conditionDescription] and [collectTimeoutDiagnostics]
/// supply the timeout message, as in [waitUntil].
Future<T> waitForFuture<T>(
  WidgetTester tester,
  Future<T> future, {
  required String conditionDescription,
  required Object? Function() collectTimeoutDiagnostics,
  Duration timeout = const Duration(seconds: 15),
  void Function()? checkHealth,
  bool checkFrameworkErrors = true,
}) async {
  var completed = false;
  late T value;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    future.then<void>(
      (result) {
        value = result;
        completed = true;
      },
      onError: (Object error, StackTrace stackTrace) {
        failure = error;
        failureStack = stackTrace;
        completed = true;
      },
    ),
  );
  await waitUntil(
    tester,
    conditionDescription: conditionDescription,
    isReady: () => completed,
    collectTimeoutDiagnostics: collectTimeoutDiagnostics,
    timeout: timeout,
    checkHealth: checkHealth,
    checkFrameworkErrors: checkFrameworkErrors,
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return value;
}
