// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/rust_message_fixture.dart' as fixture;

void main() {
  test('Rust payload fixtures match standalone Dart payload records', () {
    final snapshots = [
      VisualizationItem(
        id: 'float',
        valueType: VisualizationValueType.doubleValue,
        values: <double>[0.125, 0.25],
        sampleTimestamps: [64, 128],
      ).toJson(),
      VisualizationItem(
        id: 'integer',
        valueType: VisualizationValueType.intValue,
        values: <int>[-2, 3],
        sampleTimestamps: [64, 128],
      ).toJson(),
    ];
    _checkFixture('message_payloads', snapshots);
  });

  test('Rust IPC fixtures match Dart message serialization', () {
    final config = AudioProcessingConfigDto(
      sampleRate: 48000,
      blockSize: 256,
      inputChannelCount: 0,
      outputChannelCount: 2,
    );
    final messages = <IpcMessage>[
      Heartbeat(id: 42),
      HeartbeatReply(id: 42),
      EngineReadyCheckResponse(id: 1, success: true),
      EngineReadyCheckResponse(
        id: 2,
        success: false,
        error: 'initialization failed',
      ),
      StartAudioResponse(id: 3, success: true, audioConfig: config),
      StartRenderAudioSessionRequest(
        id: 4,
        sampleRate: 48000,
        blockSize: 256,
        outputChannelCount: 2,
      ),
      BeginFileWriteRequest(
        id: 5,
        category: 'plugin states',
        baseName: 'voice',
        extension: 'bin',
      ),
      ModelInitRequest(id: 6, serializedModel: '{"tracks":{}}'),
      ModelUpdateRequest(
        id: 7,
        updateKind: FieldUpdateKind.set,
        fieldAccesses: [
          FieldAccess(fieldType: FieldType.raw, fieldName: 'sequence'),
          FieldAccess(fieldType: FieldType.raw, fieldName: 'beatsPerMinuteRaw'),
        ],
        serializedValue: '12800',
      ),
      SetVisualizationSubscriptionsRequest(
        id: 8,
        subscriptions: [
          VisualizationSubscriptionSpec(
            id: 'meter',
            valueType: VisualizationValueType.doubleValue,
          ),
        ],
      ),
      TestSampleGainCurveResponse(
        id: 9,
        dbValues: [-6.0, 0.0],
        isNegativeInfinity: [false, false],
      ),
      PluginParameterChangedEvent(
        nodeId: 123,
        controlPortId: 4,
        value: 0.75,
        displayText: '-3 dB',
      ),
      PluginLoadedEvent(nodeId: 123),
      RenderFailedEvent(renderId: 456, error: 'cancelled'),
    ];
    final snapshots = [
      for (final message in messages)
        message.toJson(forEngine: true, forProjectFile: false),
    ];
    for (var index = 0; index < snapshots.length; index++) {
      expect(
        IpcMessage.fromJson(snapshots[index])
            .toJson(forEngine: true, forProjectFile: false),
        snapshots[index],
      );
    }
    _checkFixture('messages', snapshots);
  });

  test(
    'Rust sealed fixtures retain all inherited fields and concrete tags',
    () {
      final messages = <fixture.FixtureMessage>[
        fixture.FixtureParent.uninitialized()
          ..version = 1
          ..id = 10
          ..routing = 'parent'
          ..parentValue = 'base',
        fixture.FixtureChild.uninitialized()
          ..version = 2
          ..id = 11
          ..routing = 9
          ..parentValue = 'inherited'
          ..childValue = true,
        fixture.FixtureEvent.uninitialized()
          ..version = 3
          ..values = [1, 2, 3],
      ];
      final snapshots = [for (final message in messages) message.toJson()];
      expect(snapshots[1]['__type'], 'FixtureChild');
      for (final snapshot in snapshots) {
        expect(fixture.FixtureMessage.fromJson(snapshot).toJson(), snapshot);
      }
      _checkFixture('sealed_messages', snapshots);
    },
  );
}

void _checkFixture(String name, Object value) {
  final file = File('engine-rust/tests/fixtures/$name.json');
  if (Platform.environment['ANTHEM_UPDATE_RUST_FIXTURES'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    );
  }
  expect(
    jsonDecode(file.readAsStringSync()),
    value,
    reason: 'Regenerate Rust fixtures with ANTHEM_UPDATE_RUST_FIXTURES=1.',
  );
}
