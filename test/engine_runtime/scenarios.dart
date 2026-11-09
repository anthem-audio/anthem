// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart' as model;
import 'package:collection/collection.dart';

void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

class RuntimeSession {
  late final EngineConnectorBase connector;
  final _pending = <int, Completer<Response>>{};
  final responses = <int>[];
  final events = <IpcEvent>[];
  FutureOr<Response> Function(TestUiEchoRequest)? onEcho;

  RuntimeSession(
    EngineConnectorBase Function(void Function(IpcMessage)) connect,
  ) {
    connector = connect(_receive);
  }

  void _receive(IpcMessage message) {
    if (message is Response) {
      responses.add(message.id);
      _pending.remove(message.id)?.complete(message);
    } else if (message is TestUiEchoRequest) {
      unawaited(
        Future<Response>.sync(() => onEcho!(message))
            .then(connector.sendMessage),
      );
    } else if (message is IpcEvent) {
      events.add(message);
    }
  }

  Future<Response> request(Request message) async {
    final result = Completer<Response>();
    _pending[message.id] = result;
    connector.sendMessage(message);
    try {
      return await result.future.timeout(const Duration(seconds: 10));
    } finally {
      _pending.remove(message.id);
    }
  }

  Future<void> ready() async {
    check(
      await connector.onInit.timeout(const Duration(seconds: 15)),
      'IPC initialization failed',
    );
    final response = await request(
      EngineReadyCheckRequest(id: connector.getRequestId()),
    );
    check(
      response is EngineReadyCheckResponse && response.success,
      'Engine was not ready',
    );
  }

  Future<Map<String, dynamic>> snapshot() async {
    final reply = await request(
      GetSerializedModelFromEngineRequest(id: connector.getRequestId()),
    );
    return jsonDecode(
      (reply as GetSerializedModelFromEngineResponse).serializedModel,
    ) as Map<String, dynamic>;
  }

  Future<void> waitForExit(int expected) async {
    final deadline = Stopwatch()..start();
    while (connector.processExitCode == null) {
      if (deadline.elapsed > const Duration(seconds: 10)) {
        throw TimeoutException('Engine did not exit');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    check(
      connector.processExitCode == expected,
      'Expected exit $expected, got ${connector.processExitCode}',
    );
  }

  Future<void> close() async {
    try {
      if (connector.processExitCode == null) {
        final reply = await request(Exit(id: connector.getRequestId()));
        check(reply is ExitReply, 'Missing Exit acknowledgment');
        await waitForExit(0);
      }
    } finally {
      await connector.shutdown();
    }
  }
}

/// Exercises the same Dart models, messages, and connector APIs on both targets.
Future<void> runRuntimeScenarios(Future<RuntimeSession> Function() open) async {
  const equals = DeepCollectionEquality();
  for (var iteration = 0; iteration < 2; iteration++) {
    final session = await open();
    try {
      await session.ready();
      // Let the engine become idle before testing wakeup from the transport.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final heartbeat = await session.request(
        Heartbeat(id: session.connector.getRequestId()),
      );
      check(heartbeat is HeartbeatReply, 'Idle engine did not wake for IPC');

      final project = ProjectModel.create();
      Map<String, dynamic> snapshot() =>
          project.toJson(forEngine: true, forProjectFile: false);
      final initialized = await session.request(
        ModelInitRequest(
          id: session.connector.getRequestId(),
          serializedModel: jsonEncode(snapshot()),
        ),
      );
      check(
        initialized is ModelInitResponse && initialized.success,
        'Project initialization failed',
      );
      check(
        equals.equals(await session.snapshot(), snapshot()),
        'Initial project differs',
      );

      void changed(model.ModelChangeEvent change) {
        if (change.sendToEngine) {
          session.connector.sendMessage(
            ModelUpdateRequest.fromChange(
              id: session.connector.getRequestId(),
              change: change,
            ),
          );
        }
      }

      project.addRawFieldChangedListener(changed);
      Future<void> update(void Function() mutate) async {
        mutate();
        check(
          equals.equals(await session.snapshot(), snapshot()),
          'Project differs after mutation',
        );
      }

      try {
        await update(() {
          project.sequence.beatsPerMinuteRaw = 13550;
        });
        await update(() {
          project.tracks.values.first.name = 'A "quoted" name\\with\nlines 🎵';
        });
        await update(() {
          project.sequence.activePatternID = null;
        });
        await update(() {
          project.sequence.activePatternID = 123;
        });
        final pattern = PatternModel(
          idAllocator: project.idAllocator,
          name: 'Sync pattern',
        );
        await update(() {
          project.sequence.patterns[pattern.id] = pattern;
        });
        final note = NoteModel(
          idAllocator: project.idAllocator,
          key: 60,
          velocity: 0.75,
          length: 96,
          offset: 12,
          pan: 0,
        );
        await update(() {
          pattern.notes[note.id] = note;
        });
        await update(() {
          note.key = 65;
          note.velocity = 0.5;
        });
        final replacement = NoteModel.fromNoteModel(note)..key = 67;
        await update(() {
          pattern.notes[note.id] = replacement;
        });
        await update(() {
          replacement.offset = 24;
        });
        await update(() {
          pattern.notes.remove(note.id);
        });
        await update(() {
          project.trackOrder.add(999);
        });
        await update(() {
          project.trackOrder[project.trackOrder.length - 1] = 998;
        });
        await update(() {
          project.trackOrder.removeLast();
        });
        await update(() {
          project.trackOrder = model.AnthemObservableList.of(
            project.trackOrder.reversed,
          );
        });
        final node = project.processingGraph.nodes.values.first;
        await update(() {
          node.processorStateRetentionId = 'processor-state-test';
        });
        await update(() {
          node.processorStateRetentionId = null;
        });
        // Larger than the web ring: framing must survive partial writes and wraps.
        await update(() {
          project.tracks.values.first.name = List.filled(
            20000,
            '🎵"\\\n',
          ).join();
        });

        final heldReply = Completer<Response>();
        final heldRequest = Completer<TestUiEchoRequest>();
        session.onEcho = (request) async {
          if (request.value == 'held') {
            heldRequest.complete(request);
            return heldReply.future;
          }
          final ready = await session.request(
            EngineReadyCheckRequest(id: session.connector.getRequestId()),
          );
          check(
            ready is EngineReadyCheckResponse && ready.success,
            'Nested request blocked',
          );
          return TestUiEchoResponse(id: request.id, value: request.value);
        };
        Future<TestUiEchoRoundTripResponse> echo(
          String value, {
          int timeout = 5000,
        }) async => await session.request(
          TestUiEchoRoundTripRequest(
            id: session.connector.getRequestId(),
            value: value,
            timeoutMilliseconds: timeout,
          ),
        ) as TestUiEchoRoundTripResponse;
        var completed = false;
        // Both peers can have an outstanding request with ID zero. Requests
        // and responses must be dispatched by their role, not just their ID.
        session.connector.requestIdGen = 0;
        final held = echo('held').then((reply) {
          completed = true;
          return reply;
        });
        final uiRequest = await heldRequest.future;
        check(uiRequest.id == 0, 'Engine request IDs did not start fresh');
        await update(() {
          project.sequence.beatsPerMinuteRaw = 14000;
        });
        check(
          (await echo('nested')).value == 'nested',
          'Concurrent round trip failed',
        );
        check(!completed, 'Held request completed before the UI replied');
        heldReply.complete(
          TestUiEchoResponse(id: uiRequest.id, value: uiRequest.value),
        );
        check((await held).value == 'held', 'Suspended task did not resume');

        for (final code in RequestErrorCode.values) {
          session.onEcho = (request) => RequestErrorResponse(
            id: request.id,
            code: code,
            message: 'Remote ${code.name}',
          );
          check(
            (await echo('error')).error == 'Remote ${code.name}',
            'Remote error was lost',
          );
        }
        session.onEcho = (request) =>
            TestUiEchoResponse(id: request.id + 10000, value: 'wrong ID');
        check(
          (await echo('wrong ID', timeout: 100)).error ==
              'IPC request timed out.',
          'A response with the wrong ID completed a request',
        );
        final late = Completer<Response>();
        late TestUiEchoRequest lateRequest;
        session.onEcho = (request) {
          lateRequest = request;
          return late.future;
        };
        check(
          (await echo('timeout', timeout: 100)).error ==
              'IPC request timed out.',
          'Request did not time out',
        );
        late.complete(TestUiEchoResponse(id: lateRequest.id, value: 'late'));
        session.onEcho = (request) =>
            TestUiEchoResponse(id: request.id, value: request.value);
        check(
          (await echo('recovered')).value == 'recovered',
          'Timeout broke subsequent requests',
        );

        final unsupported = await session.request(
          StartRenderAudioSessionRequest(
            id: session.connector.getRequestId(),
            sampleRate: 48000,
            blockSize: 128,
            outputChannelCount: 2,
          ),
        );
        check(
          unsupported is RequestErrorResponse &&
              unsupported.code == RequestErrorCode.unsupported,
          'Unsupported request was not reported',
        );

        final pendingAtExit = Completer<TestUiEchoRequest>();
        final replyAfterExit = Completer<Response>();
        session.onEcho = (request) {
          pendingAtExit.complete(request);
          return replyAfterExit.future;
        };
        session.connector.sendMessage(
          TestUiEchoRoundTripRequest(
            id: session.connector.getRequestId(),
            value: 'pending at exit',
            timeoutMilliseconds: 30000,
          ),
        );
        final pending = await pendingAtExit.future;
        await session.close();
        replyAfterExit.complete(
          TestUiEchoResponse(id: pending.id, value: 'old session'),
        );
      } finally {
        project.removeRawFieldChangedListener(changed);
      }
    } finally {
      await session.connector.shutdown();
    }
  }

  // Cancellation may happen while a process or module is still being created.
  // shutdown() must wait for any late startup to release its owned resources.
  final cancelled = await open();
  await cancelled.connector.shutdown();
  await cancelled.connector.onInit;

  // A fatal sync error stops the real engine before any later request replies.
  for (final initial in [
    null,
    'not JSON',
    jsonEncode(
      ProjectModel.create().toJson(forEngine: true, forProjectFile: false),
    ),
  ]) {
    final session = await open();
    try {
      await session.ready();
      if (initial != null) {
        session.connector.sendMessage(
          ModelInitRequest(
            id: session.connector.getRequestId(),
            serializedModel: initial,
          ),
        );
      }
      session.connector.sendMessage(
        ModelUpdateRequest(
          id: session.connector.getRequestId(),
          updateKind: FieldUpdateKind.set,
          fieldAccesses: [
            FieldAccess(fieldType: FieldType.raw, fieldName: 'missing'),
          ],
          serializedValue: '1',
        ),
      );
      final later = session.connector.getRequestId();
      session.connector.sendMessage(EngineReadyCheckRequest(id: later));
      await session.waitForExit(1);
      check(
        !session.responses.contains(later),
        'Engine processed a request after fatal sync failure',
      );
    } finally {
      await session.connector.shutdown();
    }
  }
  final fresh = await open();
  try {
    await fresh.ready();
    await fresh.close();
  } finally {
    await fresh.connector.shutdown();
  }
}
