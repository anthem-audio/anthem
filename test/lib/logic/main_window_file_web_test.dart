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

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/archive.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:archive/archive.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:web/web.dart' as web;

import '../../helpers/browser_engine_test_helpers.dart';
import '../../helpers/browser_asset_test_helpers.dart';
import '../../helpers/file_dialog_test_helpers.dart';
import '../../fixtures/prealpha_1_project.dart';

/// The picker exposes an object URL. ZIP import must not ask XFile to buffer it.
class _SelectedArchive extends XFile {
  _SelectedArchive(Uint8List bytes, String name)
    : super(XFile.fromData(bytes).path, name: name, length: bytes.length);

  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Selected ZIP files must be read in slices.');
}

class _ControllerWithoutEngine extends MainWindowController {
  @override
  Future<ProjectId> openProject(
    ProjectModel project, {
    bool startAudio = true,
    ProjectStorage? storage,
  }) async {
    // Loading must restore claims before the controller can start the engine.
    expect(storage, isNotNull);
    expect(
      storage!.projectFiles.references,
      jsonDecode(project.fileRetentions),
    );
    registerProject(project, storage: storage);
    return project.id;
  }
}

class _DownloadDialog extends RecordingDialog {
  List<DialogButton> buttons = [];
  @override
  void showDialog(
    Widget content, {
    String? title,
    List<DialogButton>? buttons,
    bool dismissible = true,
    ValueListenable<bool>? canDismiss,
    void Function()? onDismiss,
  }) {
    super.showDialog(content, title: title, buttons: buttons);
    this.buttons = buttons ?? [];
  }

  void press(String text) =>
      buttons.singleWhere((button) => button.text == text).onPress!();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    useBrowserPackageAssets();
    await loadBrowserModule('AnthemFileSystem');
  });
  late _ControllerWithoutEngine controller;
  late ProjectModel project;
  late ProjectStorage storage;
  late FakeFileSelector selector;
  late _DownloadDialog recording;
  late DialogController dialogs;

  setUp(() {
    controller = _ControllerWithoutEngine();
    project = ProjectModel.create()..isDirty = true;
    storage = ProjectStorage.temporary();
    controller.registerProject(project, storage: storage);
    selector = FakeFileSelector();
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = original);
    final originalPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    ServiceRegistry.setSessionPreferences(SharedPreferencesAsync());
    addTearDown(() {
      ServiceRegistry.setSessionPreferences(null);
      SharedPreferencesAsyncPlatform.instance = originalPreferences;
    });
    recording = _DownloadDialog();
    dialogs = DialogController()..initialize(recording);
  });
  tearDown(() async {
    for (final id in AnthemStore.instance.projectOrder.toList()) {
      await controller.closeProjectWithoutSaving(id);
    }
  });

  Future<({String file, String retentionId})> addState() async {
    final scope = await storage.openScope();
    try {
      final write = await scope.beginWrite('plugin states', extension: 'bin');
      await files.writeFile(write.absolutePath, [1, 3, 5, 255]);
      final file = await scope.commitWrite(write.token);
      final retentionId = storage.projectFiles.retain(file);
      project.processingGraph.nodes.values.first.processorStateRetentionId =
          retentionId;
      // This file has no document claim and must not be downloaded.
      final other = await scope.beginWrite('plugin states', extension: 'bin');
      await scope.commitWrite(other.token);
      return (file: file, retentionId: retentionId);
    } finally {
      await scope.close();
    }
  }

  Future<Set<String>> roots() async {
    await files.createDirectory('/anthem/projects');
    return {
      for (final entry in await files.listEntries('/anthem/projects'))
        entry.name,
    };
  }

  test(
    'cancelling a browser download completes without changing the project',
    () async {
      final saving = controller.saveProject(
        project.id,
        false,
        dialogController: dialogs,
      );
      await Future<void>.delayed(Duration.zero);
      recording.press('Cancel');
      expect(await saving, isFalse);
      expect(project.isDirty, isTrue);
      expect(await files.entryExists(storage.rootDirectory), isFalse);
    },
  );

  for (final (operation, editDuringDownload, exportOnly) in [
    ('save', false, false),
    ('save with later edits', true, false),
    ('export', false, true),
  ]) {
    test('browser $operation and reopen preserve document files', () async {
      final (:file, :retentionId) = await addState();
      final beforeTempo = project.sequence.beatsPerMinuteRaw;
      final downloaded = Completer<({String name, Uint8List bytes})>();
      final listener = ((web.Event event) {
        final anchor = event.target;
        if (anchor == null || !anchor.isA<web.HTMLAnchorElement>()) return;
        final link = anchor as web.HTMLAnchorElement;
        if (!link.download.endsWith('.zip')) return;
        event.preventDefault();
        if (editDuringDownload) project.sequence.beatsPerMinuteRaw = 15500;
        unawaited(() async {
          try {
            final response = await web.window.fetch(link.href.toJS).toDart;
            final buffer = await response.arrayBuffer().toDart;
            downloaded.complete((
              name: link.download,
              bytes: buffer.toDart.asUint8List(),
            ));
          } catch (error, stack) {
            downloaded.completeError(error, stack);
          }
        }());
      }).toJS;
      web.document.addEventListener('click', listener);
      addTearDown(() => web.document.removeEventListener('click', listener));
      final saving = exportOnly
          ? controller.exportProjectZip(project.id, dialogController: dialogs)
          : controller.saveProject(
              project.id,
              false,
              dialogController: dialogs,
            );
      await Future<void>.delayed(Duration.zero);
      recording.press('Download');
      expect(await saving, isTrue);
      final saved = await downloaded.future;
      expect(saved.name, 'New Project.zip');
      expect(project.isDirty, editDuringDownload || exportOnly);
      expect(project.filePath, isNull);
      final decoded = ZipDecoder().decodeBytes(saved.bytes);
      expect(decoded.files.map((entry) => entry.name).toSet(), {
        'project.anthem',
        file,
      });
      final document = await decodeProjectFileBytes(
        decoded.findFile('project.anthem')!.content,
      );
      expect(document['sequence']['beatsPerMinuteRaw'], beforeTempo);

      selector.selectedFile = _SelectedArchive(saved.bytes, saved.name);
      final id = await controller.loadProject(dialogController: dialogs);
      expect(id, isNotNull);
      expect(id, isNot(project.id));
      final loaded = AnthemStore.instance.projects[id]!;
      final imported = ServiceRegistry.forProject(id!).projectStorage;
      expect(loaded.isDirty, isTrue);
      expect(loaded.filePath, isNull);
      expect(imported.rootDirectory, isNot(storage.rootDirectory));
      expect(imported.projectFiles.references, {retentionId: file});
      final read = imported.projectFiles.acquireRead(file);
      expect(await files.readFile(read.absolutePath), [1, 3, 5, 255]);
      imported.projectFiles.releaseRead(read.token);
      await controller.closeProjectWithoutSaving(id);
      expect(await files.entryExists(imported.rootDirectory), isFalse);
      expect(recording.shownCount, 1);
    });
  }

  test(
    'failed ZIP document loading removes the extracted working directory',
    () async {
      final bytes = ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.bytes('project.anthem', [1, 2, 3])),
      );
      selector.selectedFile = XFile.fromData(bytes, name: 'Invalid.zip');
      final before = await roots();
      expect(await controller.loadProject(dialogController: dialogs), isNull);
      expect(await roots(), before);
      expect(recording.shownCount, 1);
    },
  );

  test('browser imports reject invalid paths and corrupted contents without leaving files', () async {
    final document = await encodeProjectFile(project);
    final before = await roots();
    for (final name in [
      '../outside.bin',
      'plugin states/CON',
      'plugin states/../outside.bin',
    ]) {
      final bytes = ZipEncoder().encodeBytes(
        Archive()
          ..add(ArchiveFile.bytes('project.anthem', document))
          ..add(ArchiveFile.bytes(name, [1, 2, 3])),
      );
      await expectLater(
        extractProjectArchiveBytes(bytes),
        throwsA(isA<InvalidProjectFileException>()),
      );
      expect(await roots(), before);
    }
    final bytes = ZipEncoder().encodeBytes(
      Archive()
        ..add(ArchiveFile.bytes('project.anthem', document))
        ..add(
          ArchiveFile.noCompress('plugin states/state.bin', 5, [
            231,
            132,
            91,
            64,
            202,
          ]),
        ),
    );
    final position = latin1
        .decode(bytes)
        .indexOf(latin1.decode([231, 132, 91, 64, 202]));
    expect(position, greaterThan(0));
    bytes[position] = 230;
    await expectLater(
      extractProjectArchiveBytes(bytes),
      throwsA(isA<InvalidProjectFileException>()),
    );
    expect(await roots(), before);
  });

  test('missing referenced assets fail before project registration and remove extraction', () async {
    await addState();
    final json = project.toJson()
      ..['fileRetentions'] = jsonEncode(storage.projectFiles.references);
    final bytes = ZipEncoder().encodeBytes(
      Archive()..add(
        ArchiveFile.bytes('project.anthem', await encodeProjectJson(json)),
      ),
    );
    selector.selectedFile = XFile.fromData(bytes, name: 'Missing.zip');
    final before = await roots();
    expect(await controller.loadProject(dialogController: dialogs), isNull);
    expect(AnthemStore.instance.projectOrder, [project.id]);
    expect(await roots(), before);
  });

  test(
    'standalone documents without external files still open in the browser',
    () async {
      selector.selectedFile = XFile.fromData(
        await encodeProjectFile(project),
        name: 'Document.anthem',
      );
      // A saved document can be reopened after its original tab closes.
      await controller.closeProjectWithoutSaving(project.id);
      final id = await controller.loadProject(dialogController: dialogs);
      expect(id, isNotNull);
      final loaded = AnthemStore.instance.projects[id]!;
      expect(loaded.filePath, isNull);
      expect(
        ServiceRegistry.forProject(id!).projectStorage.isTemporary,
        isTrue,
      );
      expect(recording.shownCount, 0);
    },
  );

  test(
    'legacy single-file projects migrate processor state into browser storage',
    () async {
      final json = jsonDecode(prealpha1ProjectJson) as Map<String, dynamic>;
      selector.selectedFile = XFile.fromData(
        await encodeProjectJson(json),
        name: 'Old.anthem',
      );
      final id = await controller.loadProject(dialogController: dialogs);
      expect(id, isNotNull);
      final imported = ServiceRegistry.forProject(id!).projectStorage;
      expect(imported.projectFiles.references, isNotEmpty);
      for (final file in imported.projectFiles.references.values) {
        final read = imported.projectFiles.acquireRead(file);
        expect(
          utf8.decode((await files.readFile(read.absolutePath)).sublist(0, 8)),
          'ANTHST01',
        );
        imported.projectFiles.releaseRead(read.token);
      }
      final saved = await PreparedProjectSave.prepare(
        AnthemStore.instance.projects[id]!,
        imported,
      );
      try {
        final zip = await encodeProjectArchive(saved);
        expect(ZipDecoder().decodeBytes(zip).files.length, greaterThan(1));
      } finally {
        await saved.close();
      }
    },
  );
}
