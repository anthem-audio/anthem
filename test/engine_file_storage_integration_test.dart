/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'dart:async';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/engine_connector_desktop.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class _StorageConnector extends EngineConnector {
  bool dropNextWriteReply = false;
  Completer<void>? shutdownGate;
  final shutdownEntered = Completer<void>();
  final droppedWriteReply = Completer<BeginFileWriteResponse>();

  _StorageConnector(
    super.id, {
    required super.kDebugMode,
    super.noHeartbeat,
    super.enginePathOverride,
    super.onMessage,
    super.onExit,
    super.onConnectionClosed,
  });

  @override
  Future<void> shutdown({Duration timeout = const Duration(seconds: 5)}) async {
    if (!shutdownEntered.isCompleted) shutdownEntered.complete();
    await shutdownGate?.future;
    await super.shutdown(timeout: timeout);
  }

  @override
  void sendMessage(IpcMessage message) {
    if (dropNextWriteReply && message is BeginFileWriteResponse) {
      dropNextWriteReply = false;
      droppedWriteReply.complete(message);
      return;
    }
    super.sendMessage(message);
  }
}

class _StorageFixture {
  final ProjectModel project;
  final storage = ProjectStorage.temporary();
  final messages = StreamController<IpcMessage>.broadcast();
  final readyHeld = Completer<EngineReadyCheckResponse>();
  bool holdStartup;
  late _StorageConnector connector;
  void Function(IpcMessage)? _deliver;

  Engine get engine => project.engine;
  _StorageFixture._(this.project, this.holdStartup);

  static Future<_StorageFixture> create({bool holdStartup = false}) async {
    final suffix = Platform.isWindows ? '.exe' : '';
    final candidates = [
      'engine/build/AnthemEngine_artefacts/Debug/AnthemEngine$suffix',
      'engine/build_release/AnthemEngine_artefacts/Release/AnthemEngine$suffix',
    ];
    final executable = candidates
        .map(File.new)
        .where((f) => f.existsSync())
        .first
        .absolute
        .path;
    final project = ProjectModel.create(executable);
    await project.engine.dispose();
    final fixture = _StorageFixture._(project, holdStartup);
    project.engine = Engine(
      project.engineID,
      project,
      enginePathOverride: executable,
      engineConnectorFactory: fixture._createConnector,
    );
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectStorageService, (_, _) => fixture.storage),
      ]),
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  EngineConnectorBase _createConnector(
    int id, {
    required bool kDebugMode,
    void Function(IpcMessage)? onMessage,
    void Function()? onExit,
    void Function()? onConnectionClosed,
    bool noHeartbeat = false,
    String? enginePathOverride,
  }) {
    _deliver = onMessage;
    return connector = _StorageConnector(
      id,
      kDebugMode: kDebugMode,
      noHeartbeat: true,
      enginePathOverride: enginePathOverride,
      onExit: onExit,
      onConnectionClosed: onConnectionClosed,
      onMessage: (message) {
        messages.add(message);
        if (holdStartup && message is EngineReadyCheckResponse) {
          readyHeld.complete(message);
          return;
        }
        onMessage?.call(message);
      },
    );
  }

  Future<void> releaseStartup() async {
    holdStartup = false;
    _deliver!(await readyHeld.future);
  }

  Future<TestFileStorageResponse> send(
    TestFileStorageOperation operation, {
    String category = 'plugin states',
    String? baseName,
    String? extension,
    String data = '',
    String token = '',
    String relativePath = '',
  }) async {
    final id = connector.getRequestId();
    final response = messages.stream.firstWhere(
      (message) => message is TestFileStorageResponse && message.id == id,
    );
    connector.sendMessage(
      TestFileStorageRequest(
        id: id,
        operation: operation,
        category: category,
        baseName: baseName,
        extension: extension,
        data: data,
        token: token,
        relativePath: relativePath,
      ),
    );
    return await response.timeout(const Duration(seconds: 10))
        as TestFileStorageResponse;
  }

  Future<void> dispose() async {
    await engine.dispose();
    await storage.discard();
    ServiceRegistry.removeProject(project.id);
    project.dispose();
    await messages.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the engine writes and reads through production storage requests during startup and render holds', () async {
    final fixture = await _StorageFixture.create(holdStartup: true);
    final startup = fixture.engine.start(initializeAudio: false);
    await fixture.readyHeld.future;
    expect(fixture.engine.engineState, EngineState.starting);
    final write = await fixture.send(
      TestFileStorageOperation.beginWrite,
      baseName: 'Preset Ω',
      extension: 'bin',
      data: 'opaque state Ω\u0000tail',
    );
    expect(write.error, isNull);
    final store = await fixture.storage.fileStore;
    final uiScope = store.openScope();
    addTearDown(() => store.closeScope(uiScope));
    expect(store.relativePaths, isEmpty);
    final committed = await fixture.send(
      TestFileStorageOperation.commitWrite,
      token: write.token!,
    );
    expect(committed.error, isNull);
    expect(committed.relativePath, 'plugin states/Preset Ω 01.bin');
    await fixture.releaseStartup();
    await startup;
    fixture.engine.holdRequestsForRender();
    final read = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: committed.relativePath!,
    );
    expect(read.error, isNull);
    expect(read.data, 'opaque state Ω\u0000tail');
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      contains('still in use'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRead,
        token: read.token!,
      )).error,
      isNull,
    );
    final retained = store.retain(uiScope, committed.relativePath!);
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      contains('still in use'),
    );
    store.releaseRetention(uiScope, retained);
    final engineRetention = await fixture.send(
      TestFileStorageOperation.retainFile,
      relativePath: committed.relativePath!,
    );
    expect(engineRetention.error, isNull);
    expect(
      () => store.delete(uiScope, committed.relativePath!),
      throwsStateError,
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRetention,
        token: engineRetention.token!,
      )).error,
      isNull,
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      isNull,
    );
    expect(await File(read.absolutePath!).exists(), isFalse);
    final aborted = await fixture.send(
      TestFileStorageOperation.beginWrite,
      baseName: 'Discard',
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.abortWrite,
        token: aborted.token!,
      )).error,
      isNull,
    );
    expect(await File(aborted.absolutePath!).exists(), isFalse);
    expect(
      (await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: aborted.token!,
      )).error,
      contains('Unknown file write token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.beginWrite,
        category: '../outside',
      )).error,
      contains('Unknown file category'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: '../outside',
      )).error,
      contains('Expected a category/filename path'),
    );
    fixture.engine.releaseRequestsHeldForRender();
  }, timeout: const Timeout(Duration(seconds: 45)));

  test(
    'UI writes are available to the engine after the UI file scope closes',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final store = await fixture.storage.fileStore;
      final uiScope = store.openScope();
      addTearDown(() => store.closeScope(uiScope));
      final write = await store.beginWrite(
        uiScope,
        'plugin states',
        baseName: 'Created by UI',
      );
      await File(write.absolutePath).writeAsString('shared state', flush: true);
      expect(
        (await fixture.send(
          TestFileStorageOperation.commitWrite,
          token: write.token,
        )).error,
        contains('Unknown file write token'),
      );
      final relativePath = await store.commitWrite(uiScope, write.token);
      final read = await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: relativePath,
      );
      expect(read.error, isNull);
      expect(read.data, 'shared state');
      store.retain(uiScope, relativePath);
      final pending = await store.beginWrite(uiScope, 'plugin states');

      await store.closeScope(uiScope);
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(await File(read.absolutePath!).readAsString(), 'shared state');
      // The engine's read token still prevents deletion after UI cleanup.
      expect(
        (await fixture.send(
          TestFileStorageOperation.deleteFile,
          relativePath: relativePath,
        )).error,
        contains('still in use'),
      );
      expect(
        (await fixture.send(
          TestFileStorageOperation.releaseRead,
          token: read.token!,
        )).error,
        isNull,
      );
      expect(
        (await fixture.send(
          TestFileStorageOperation.deleteFile,
          relativePath: relativePath,
        )).error,
        isNull,
      );
      expect(await File(read.absolutePath!).exists(), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('process exit releases reads and unfinished writes while restart keeps committed state', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    final write = await fixture.send(
      TestFileStorageOperation.beginWrite,
      data: 'saved state',
    );
    final committed = await fixture.send(
      TestFileStorageOperation.commitWrite,
      token: write.token!,
    );
    final relativePath = committed.relativePath!;
    final store = await fixture.storage.fileStore;
    final uiScope = store.openScope();
    addTearDown(() => store.closeScope(uiScope));
    final retained = store.retain(uiScope, relativePath);
    final engineRetention = await fixture.send(
      TestFileStorageOperation.retainFile,
      relativePath: relativePath,
    );
    expect(engineRetention.error, isNull);
    final read = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: relativePath,
    );
    final unfinished = await fixture.send(
      TestFileStorageOperation.beginWrite,
      data: 'unfinished',
    );
    final stopped = fixture.engine.engineStateStream.firstWhere(
      (state) => state == EngineState.stopped,
    );
    expect(
      Process.killPid(fixture.connector.processId!, ProcessSignal.sigkill),
      isTrue,
    );
    await stopped.timeout(const Duration(seconds: 15));
    expect(await File(unfinished.absolutePath!).exists(), isFalse);
    expect(await File(read.absolutePath!).readAsString(), 'saved state');
    expect(
      () => store.delete(uiScope, relativePath),
      throwsStateError,
    ); // Project retention survives.
    await fixture.engine.start(initializeAudio: false);
    expect(
      (await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: unfinished.token!,
      )).error,
      contains('Unknown file write token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRead,
        token: read.token!,
      )).error,
      contains('Unknown file read token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRetention,
        token: engineRetention.token!,
      )).error,
      contains('Unknown file retention token'),
    );
    final reread = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: relativePath,
    );
    expect(reread.data, 'saved state');
    await fixture.send(
      TestFileStorageOperation.releaseRead,
      token: reread.token!,
    );
    store.releaseRetention(uiScope, retained);
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: relativePath,
      )).error,
      isNull,
    );
    final pending = await fixture.send(TestFileStorageOperation.beginWrite);
    await fixture.engine.stop();
    expect(await File(pending.absolutePath!).exists(), isFalse);
    expect(
      await Directory(path.join(store.rootDirectory, '.pending'))
          .list()
          .toList(),
      isEmpty,
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'entering stopping preserves access until connector shutdown completes',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final write = await fixture.send(TestFileStorageOperation.beginWrite);
      final committed = await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: write.token!,
      );
      await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: committed.relativePath!,
      );
      final pending = await fixture.send(TestFileStorageOperation.beginWrite);
      final store = await fixture.storage.fileStore;
      final uiScope = store.openScope();
      addTearDown(() => store.closeScope(uiScope));
      final gate = fixture.connector.shutdownGate = Completer<void>();
      final stopping = fixture.engine.stop();
      try {
        await fixture.engine.sessionEnded;
        await fixture.connector.shutdownEntered.future;
        expect(fixture.engine.engineState, EngineState.stopping);
        expect(await File(pending.absolutePath!).exists(), isTrue);
        expect(
          () => store.delete(uiScope, committed.relativePath!),
          throwsStateError,
        );
      } finally {
        gate.complete();
        await stopping;
      }
      expect(await File(pending.absolutePath!).exists(), isFalse);
      await store.delete(uiScope, committed.relativePath!);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('failed file cleanup can be retried when closing the engine', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    final pending = await fixture.send(TestFileStorageOperation.beginWrite);
    await File(pending.absolutePath!).delete();
    await Directory(pending.absolutePath!).create();
    await expectLater(
      fixture.engine.dispose(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory(pending.absolutePath!).exists(), isTrue);
    await expectLater(
      fixture.engine.start(initializeAudio: false),
      throwsStateError,
    );
    await Directory(pending.absolutePath!).delete();
    await File(pending.absolutePath!).writeAsString('retry cleanup');
    await fixture.engine.dispose();
    expect(await File(pending.absolutePath!).exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a lost write-access reply is cleaned up after the engine times out and stops', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    fixture.connector.dropNextWriteReply = true;
    final pending = fixture.send(TestFileStorageOperation.beginWrite);
    final lost = await fixture.connector.droppedWriteReply.future;
    expect((await pending).error, 'IPC request timed out.');
    expect(await File(lost.absolutePath).exists(), isTrue);
    await fixture.engine.stop();
    expect(await File(lost.absolutePath).exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
