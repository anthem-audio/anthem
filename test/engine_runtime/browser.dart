// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:js_interop';

import 'package:anthem/engine_api/engine_connector_web.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'scenarios.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final result = <String, Object?>{};
  try {
    var id = 0;
    await runRuntimeScenarios(
      () async => RuntimeSession(
        (receive) => EngineConnector(
          ++id,
          kDebugMode: false,
          noHeartbeat: true,
          onMessage: receive,
        ),
      ),
    );
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
