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

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedTempoChange extends Command {
  final Future<void> ready;
  late int previousTempo;

  _DelayedTempoChange(this.ready);

  @override
  Future<void> execute(ProjectModel project) async {
    previousTempo = project.sequence.beatsPerMinuteRaw;
    await ready;
    project.sequence.beatsPerMinuteRaw = 15000;
  }

  @override
  void rollback(ProjectModel project) =>
      project.sequence.beatsPerMinuteRaw = previousTempo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;
  late ProjectStorage storage;
  late AssetScope writer;

  setUp(() async {
    project = ProjectModel.create();
    storage = ProjectStorage.temporary();
    writer = await storage.openScope();
  });

  tearDown(() async {
    await writer.close();
    await project.dispose();
    await storage.discard();
  });

  Future<String> asset(String content) async {
    final write = await writer.beginWrite('plugin states', extension: 'bin');
    await File(write.absolutePath).writeAsString(content);
    return writer.commitWrite(write.token);
  }

  test(
    'preparation captures project claims without changing the live manifest',
    () async {
      final current = await asset('current');
      final runtimeOnly = await asset('undo history');
      await asset('unreferenced');
      final id = storage.projectFiles.retain(current);
      final history = storage.retainAssets([runtimeOnly]);
      addTearDown(history.dispose);
      final before = project.toJson();

      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      expect(prepared.projectJson, {
        ...before,
        'fileRetentions': jsonEncode({id: current}),
      });
      expect(prepared.assets.references, {id: current});
      expect(prepared.assets.reads.keys, [current]);
      expect(prepared.changedDuringSave, isFalse);
      expect(project.toJson(), before);
      expect(
        project.toJson(forEngine: true, forProjectFile: false),
        isNot(contains('fileRetentions')),
      );
    },
  );

  test(
    'preparation freezes matching document data and files through later edits',
    () async {
      final original = await asset('original state');
      final id = storage.projectFiles.retain(original);
      final beforeTempo = project.sequence.beatsPerMinuteRaw;
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);

      storage.projectFiles.releaseRetention(id);
      final replacement = await asset('replacement state');
      storage.projectFiles.retain(replacement);
      project.sequence.beatsPerMinuteRaw = beforeTempo + 100;

      expect(prepared.changedDuringSave, isTrue);
      expect(
        prepared.projectJson['sequence']['beatsPerMinuteRaw'],
        beforeTempo,
      );
      expect(jsonDecode(prepared.projectJson['fileRetentions'] as String), {
        id: original,
      });
      expect(prepared.assets.references, {id: original});
      expect(prepared.assets.reads.keys, [original]);
      expect(
        await File(prepared.assets.reads[original]!.absolutePath)
            .readAsString(),
        'original state',
      );
      expect(() => writer.delete(original), throwsStateError);
      await prepared.close();
      await writer.delete(original);
      expect(() => writer.delete(replacement), throwsStateError);
    },
  );

  test('closing releases reads and stops watching the project', () async {
    final file = await asset('state');
    final id = storage.projectFiles.retain(file);
    final prepared = await PreparedProjectSave.prepare(project, storage);
    addTearDown(prepared.close);
    storage.projectFiles.releaseRetention(id);
    expect(() => writer.delete(file), throwsStateError);

    await prepared.close();
    await prepared.close();
    project.sequence.beatsPerMinuteRaw = 15000;
    expect(prepared.changedDuringSave, isFalse);
    await writer.delete(file);
  });

  test(
    'preparation waits for pending commands before capturing the document',
    () async {
      final ready = Completer<void>();
      final command = project.execute(_DelayedTempoChange(ready.future));
      var finished = false;
      final preparing = PreparedProjectSave.prepare(project, storage).then((
        prepared,
      ) {
        finished = true;
        return prepared;
      });
      addTearDown(() async {
        if (!ready.isCompleted) ready.complete();
        await (await preparing).close();
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);

      ready.complete();
      await command;
      final prepared = await preparing;
      expect(prepared.projectJson['sequence']['beatsPerMinuteRaw'], 15000);
      expect(prepared.changedDuringSave, isFalse);
    },
  );
}
