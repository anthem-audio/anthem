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
import 'dart:convert';
import 'dart:typed_data';

import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:flutter_test/flutter_test.dart';

class _Connector extends EngineConnectorBase {
  final List<IpcMessage> sent = [];

  _Connector({super.onMessage, super.onConnectionClosed})
    : super(kDebugMode: false, noHeartbeat: true) {
    onInit = Future.value(true);
  }

  @override
  void sendBytes(Uint8List bytes) {
    sent.add(
      IpcMessage.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      ),
    );
  }

  @override
  void finalizeVisualizationSharedMemorySetup() {}

  void receive(IpcMessage response) {
    receiveMany([response]);
  }

  void receiveMany(Iterable<IpcMessage> responses) {
    final frames = BytesBuilder();
    for (final response in responses) {
      final bytes = utf8.encode(jsonEncode(response.toJson()));
      final frame = Uint8List(bytes.length + 8);
      ByteData.sublistView(frame).setUint32(
        Endian.host == Endian.little ? 0 : 4,
        bytes.length,
        Endian.host,
      );
      frame.setRange(8, frame.length, bytes);
      frames.add(frame);
    }
    onReceive(frames.takeBytes());
  }
}

void main() {
  test('messages decode by role without directional wrappers', () {
    final messages = <IpcMessage>[
      EngineReadyCheckRequest(id: 0),
      TestUiEchoRequest(id: 0, value: 'hello'),
      EngineReadyCheckResponse(id: 0, success: true),
      TestUiEchoResponse(id: 0, value: 'hello'),
      AudioSessionInvalidatedEvent(reason: 'device disconnected'),
    ];
    for (final message in messages) {
      final json = message.toJson();
      final decoded = IpcMessage.fromJson(json);
      expect(decoded.runtimeType, message.runtimeType);
      expect(decoded.toJson(), json);
      if (message is IpcEvent) {
        expect(json.containsKey('id'), isFalse);
        expect(decoded, isA<IpcEvent>());
        expect(() => Response.fromJson(json), throwsFormatException);
      }
    }
    expect(messages[0], isA<Request>());
    expect(messages[1], isA<Request>());
    expect(messages[2], isA<Response>());
    expect(messages[3], isA<Response>());
  });

  test('forwards requests, responses, events, and heartbeat replies', () {
    final received = <IpcMessage>[];
    final connector = _Connector(onMessage: received.add);
    addTearDown(connector.dispose);
    final messages = <IpcMessage>[
      TestUiEchoRequest(id: 0, value: 'hello'),
      EngineReadyCheckResponse(id: 0, success: true),
      AudioSessionInvalidatedEvent(reason: 'device disconnected'),
      HeartbeatReply(id: 1),
    ];

    connector.receiveMany(messages);

    expect(
      received.map((message) => message.toJson()),
      messages.map((message) => message.toJson()),
    );
    expect(connector.sent, isEmpty);
  });

  test('visualization records are not forwarded as JSON messages', () {
    final received = <IpcMessage>[];
    final connector = _Connector(onMessage: received.add);
    addTearDown(connector.dispose);

    connector.handleVisualizationRecord(
      const VisualizationRecord(
        sequence: 1,
        generation: 1,
        sampleRate: 48000,
        newestSampleTimestamp: 0,
        items: [],
      ),
    );

    expect(received, isEmpty);
  });

  test(
    'closing a connection suppresses incoming and outgoing messages',
    () async {
      final received = <IpcMessage>[];
      final closed = Completer<void>();
      var closureNotifications = 0;
      final connector = _Connector(
        onMessage: received.add,
        onConnectionClosed: () {
          closureNotifications++;
          closed.complete();
        },
      );
      final messages = <IpcMessage>[
        EngineReadyCheckRequest(id: 10),
        TestUiEchoResponse(id: 11, value: 'hello'),
        AudioSessionInvalidatedEvent(reason: 'device disconnected'),
      ];
      for (final message in messages) {
        connector.sendMessage(message);
      }
      expect(
        connector.sent.map((message) => message.toJson()),
        messages.map((message) => message.toJson()),
      );

      connector.dispose();
      connector.dispose();
      await closed.future;
      expect(closureNotifications, 1);
      for (final message in messages) {
        connector.sendMessage(message);
      }
      connector.receive(TestUiEchoRequest(id: 12, value: 'ignored'));

      expect(connector.sent, hasLength(messages.length));
      expect(received, isEmpty);
    },
  );

  test('closing during dispatch stops delivery of the remaining batch', () {
    late _Connector connector;
    var handled = 0;
    connector = _Connector(
      onMessage: (_) {
        handled++;
        connector.dispose();
      },
    );
    connector.receiveMany([
      TestUiEchoRequest(id: 0, value: 'close'),
      TestUiEchoRequest(id: 1, value: 'ignored'),
    ]);
    expect(handled, 1);
  });
}
