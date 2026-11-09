// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:anthem/engine_api/engine_connector_desktop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio.dart';
import 'scenarios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dart ↔ Rust runtime and model sync', () async {
    var id = 0;
    final engine =
        Platform.environment['ANTHEM_RUST_ENGINE'] ??
        'engine-rust/target/debug/anthem-engine${Platform.isWindows ? '.exe' : ''}';
    RuntimeSession open() => RuntimeSession(
      (receive) => EngineConnector(
        ++id,
        kDebugMode: false,
        noHeartbeat: true,
        enginePathOverride: File(engine).absolute.path,
        onMessage: receive,
      ),
    );
    await runRuntimeScenarios(() async => open());
    if (Platform.environment['ANTHEM_TEST_AUDIO'] == '1') {
      await runAudioLifecycle(open());
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
