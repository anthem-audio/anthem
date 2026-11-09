// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:anthem/engine_api/engine_connector_web.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'audio.dart';
import 'scenarios.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final result = <String, Object?>{};
  try {
    var id = 0;
    RuntimeSession open() => RuntimeSession(
      (receive) => EngineConnector(
        ++id,
        kDebugMode: false,
        noHeartbeat: true,
        onMessage: receive,
      ),
    );
    await runRuntimeScenarios(() async => open());
    if (const bool.fromEnvironment('ANTHEM_TEST_AUDIO')) {
      final session = open();
      final connector = session.connector as EngineConnector;
      await runAudioLifecycle(
        session,
        renderedBlocks: () => connector.engineInterface.appInstance
            .callMethod<JSNumber>('_getAudioRenderedBlocks'.toJS)
            .toDartInt,
      );
    }
    result['success'] = true;
  } catch (error, stack) {
    result.addAll({'success': false, 'error': '$error', 'stack': '$stack'});
  }
  await web.window
      .fetch(
        '/__result'.toJS,
        web.RequestInit(method: 'POST', body: jsonEncode(result).toJS),
      )
      .toDart;
}
