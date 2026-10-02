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

import 'dart:io';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/sequence_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_test_session.dart';
import 'support/piano_roll_test_driver.dart';
import 'support/temporary_project_file_selector.dart';
import 'support/waits.dart';

const _trackName = 'Persistence track';
const _patternName = 'Persistence melody';

Map<String, Object> _expectedNote(Id id) => {
  'id': id,
  'key': 67,
  'offset': 48,
  'length': 72,
  'velocity': 0.75,
  'pan': -0.125,
};

Future<({Id trackId, Id patternId, Id noteId})> _prepareEditedProject(
  AppTestSession session,
) async {
  final project = session.project;
  final trackId = project.trackOrder.first;
  project.tracks[trackId]!.name = _trackName;
  final pattern = PatternModel(
    idAllocator: project.idAllocator,
    name: _patternName,
  );
  final note = NoteModel(
    idAllocator: project.idAllocator,
    key: 67,
    offset: 48,
    length: 72,
    velocity: 0.75,
    pan: -0.125,
  );
  pattern.notes[note.id] = note;
  project.sequence.patterns[pattern.id] = pattern;
  // Fixture data is deliberate; this command makes the project an edited,
  // dirty project through the application's normal undoable edit path.
  project.execute(
    SetTempoCommand(
      newRawTempo: 13700,
      oldRawTempo: project.sequence.beatsPerMinuteRaw,
    ),
  );
  expect(project.isDirty, isTrue);
  await _verifyContent(
    session,
    trackId: trackId,
    patternId: pattern.id,
    noteId: note.id,
  );
  return (trackId: trackId, patternId: pattern.id, noteId: note.id);
}

Future<void> _verifyContent(
  AppTestSession session, {
  required Id trackId,
  required Id patternId,
  required Id noteId,
}) async {
  final project = session.project;
  expect(project.trackOrder, [trackId]);
  expect(project.tracks[trackId]!.name, _trackName);
  expect(project.sequence.beatsPerMinuteRaw, 13700);
  expect(project.sequence.patterns.keys, [patternId]);
  final pattern = project.sequence.patterns[patternId]!;
  expect(pattern.name, _patternName);
  expect(pattern.notes.keys, [noteId]);
  expect(pattern.notes[noteId]!.toJson(), _expectedNote(noteId));
  final model = await session.waitForEngineModel(
    conditionDescription:
        'persistent track, pattern, tempo, and note properties',
    matches: (model) {
      final sequence = model['sequence'] as Map;
      final patterns = sequence['patterns'] as Map;
      final enginePattern = patterns['$patternId'] as Map?;
      final notes = enginePattern?['notes'] as Map?;
      final engineNote = notes?['$noteId'] as Map?;
      final tracks = model['tracks'] as Map;
      return (model['trackOrder'] as List).single == trackId &&
          (tracks['$trackId'] as Map?)?['name'] == _trackName &&
          sequence['beatsPerMinuteRaw'] == 13700 &&
          patterns.length == 1 &&
          enginePattern?['name'] == _patternName &&
          notes?.length == 1 &&
          engineNote != null &&
          _expectedNote(noteId).entries
              .every((entry) => engineNote[entry.key] == entry.value);
    },
  );
  await session.writeSessionDiagnostics(
    'verified-content',
    additionalDiagnostics: {
      'dartPersistentContent': project.toJson(),
      'engineModel': model,
    },
  );
}

Future<bool> _save(AppTestSession session, {bool saveAs = true}) =>
    waitForFuture(
      session.tester,
      ServiceRegistry.mainWindowController.saveProject(
        session.project.id,
        saveAs,
        dialogController: ServiceRegistry.dialogController,
      ),
      conditionDescription: saveAs
          ? 'application Save As workflow'
          : 'application Save workflow',
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      checkHealth: session.checkEngine,
    );

void _expectSameOpenProject(AppTestSession session, ProjectModel original) {
  expect(session.project, same(original));
  expect(AnthemStore.instance.projects.values, [original]);
  expect(AnthemStore.instance.projectOrder, [original.id]);
  expect(AnthemStore.instance.activeProjectId, original.id);
  session.checkEngine();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save an edited project, close it, and reopen its file', (
    tester,
  ) async {
    final files = await TemporaryProjectFileSelector.install(
      'project-persistence',
    );
    final session = AppTestSession(tester, name: 'project-persistence');
    await session.start();
    final original = session.project;
    final ids = await _prepareEditedProject(session);
    final originalPid = original.engine.processId;
    final originalEngineId = original.engine.id;
    files.selectedSavePath = files.pathFor('saved-melody');
    expect(await _save(session), isTrue);
    final savedPath = files.pathFor('saved-melody.anthem');
    expect(original.filePath, savedPath);
    expect(original.isDirty, isFalse);
    expect(await File(savedPath).length(), greaterThan(0));
    expect(files.saveCount, 1);
    final savedPersistentContent = original.toJson();
    // Keep a diagnostic copy outside the temporary directory before closing.
    await File(savedPath)
        .copy('${session.artifacts.path}/saved-project.anthem');
    await session.writeSessionDiagnostics(
      'saved',
      additionalDiagnostics: {
        'persistentContent': original.toJson(),
        'savedPath': savedPath,
      },
    );

    expect(
      await waitForFuture(
        tester,
        session.services.projectController.close(),
        conditionDescription: 'close the saved project',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      ),
      isTrue,
    );
    await waitForFuture(
      tester,
      original.engine.dispose(),
      conditionDescription: 'closed project engine exit',
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    );
    await tester.pump();
    expect(original.engine.processExitCode, isNotNull);
    expect(AnthemStore.instance.projects, isEmpty);
    expect(ServiceRegistry.maybeForProject(original.id), isNull);
    await tester.tap(find.text('File'));
    await tester.pump();
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Load project...'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Save as...'), findsNothing);
    ServiceRegistry.screenOverlayController.clear();
    await tester.pump();
    await session.writeSessionDiagnostics('closed-before-reopen');

    files.selectedOpenPath = savedPath;
    final reopened = await session.openProjectFromFile();
    expect(reopened, isNotNull);
    expect(reopened, isNot(same(original)));
    expect(reopened!.id, original.id);
    expect(reopened.filePath, savedPath);
    expect(reopened.isDirty, isFalse);
    expect(reopened.toJson(), savedPersistentContent);
    expect(reopened.engine.id, isNot(originalEngineId));
    expect(reopened.engine.processId, isNot(originalPid));
    expect(files.openCount, 1);
    await _verifyContent(
      session,
      trackId: ids.trackId,
      patternId: ids.patternId,
      noteId: ids.noteId,
    );

    session.services.trackController.setActiveTrack(ids.trackId);
    final pianoRoll = PianoRollTestDriver(session);
    await pianoRoll.configureFixture(
      patternId: ids.patternId,
      timeStart: 0,
      timeEnd: 384,
      pitchAtTop: 72,
      keyHeight: 16,
      tool: EditorTool.pencil,
      noteLength: 72,
      noteVelocity: 0.75,
      notePan: -0.125,
      expectedSnapTicks: 24,
    );
    await pianoRoll.waitForNoteRendering(ids.noteId, visible: true);
    expect(
      pianoRoll.viewModel.visibleNotes.getAnnotations().map(
        (note) => note.metadata.realNoteId,
      ),
      [ids.noteId],
    );
    expect(reopened.isDirty, isFalse);
    await session.writeSessionDiagnostics(
      'reopened',
      additionalDiagnostics: {
        'pianoRoll': pianoRoll.viewportDiagnostics,
        'persistentContent': reopened.toJson(),
        'previousEnginePid': originalPid,
        'previousEngineExitCode': original.engine.processExitCode,
      },
    );
    await session.dispose();
    expect(reopened.engine.processExitCode, isNotNull);
    expect(AnthemStore.instance.projects, isEmpty);
  });

  testWidgets(
    'cancelled selection and failed writes preserve the open project',
    (tester) async {
      final files = await TemporaryProjectFileSelector.install(
        'persistence-cancellation',
      );
      final session = AppTestSession(tester, name: 'persistence-cancellation');
      await session.start();
      final original = session.project;
      final ids = await _prepareEditedProject(session);
      final before = original.toJson();
      expect(await _save(session), isFalse);
      expect(await session.openProjectFromFile(), isNull);
      _expectSameOpenProject(session, original);
      expect(original.toJson(), before);
      expect(original.filePath, isNull);
      expect(original.isDirty, isTrue);
      expect(await files.directory.list().toList(), isEmpty);
      expect(find.text('Could not open project'), findsNothing);

      files.selectedSavePath = files.pathFor('existing.anthem');
      expect(await _save(session), isTrue);
      final savedBytes = await File(original.filePath!).readAsBytes();
      original.execute(SetTempoCommand(newRawTempo: 13900, oldRawTempo: 13700));
      final edited = original.toJson();
      files.selectedSavePath = files.pathFor('missing-directory/song');
      await expectLater(
        () => _save(session),
        throwsA(isA<FileSystemException>()),
      );
      _expectSameOpenProject(session, original);
      expect(original.filePath, files.pathFor('existing.anthem'));
      expect(original.isDirty, isTrue);
      expect(original.toJson(), edited);
      expect(await File(original.filePath!).readAsBytes(), savedBytes);
      expect(
        File(files.pathFor('missing-directory/song.anthem')).existsSync(),
        isFalse,
      );

      // Ordinary Save must reuse the existing path without asking for selection.
      expect(await _save(session, saveAs: false), isTrue);
      expect(files.saveCount, 3);
      expect(files.openCount, 1);
      expect(original.isDirty, isFalse);
      await session.waitForEngineModel(
        conditionDescription: 'edited tempo after ordinary Save',
        matches: (model) =>
            (model['sequence'] as Map)['beatsPerMinuteRaw'] == 13900,
      );
      expect(
        original.sequence.patterns[ids.patternId]!.notes[ids.noteId]!.toJson(),
        _expectedNote(ids.noteId),
      );
      await session.dispose();
    },
  );

  testWidgets(
    'read failures show the application dialog without replacing the project',
    (tester) async {
      final files = await TemporaryProjectFileSelector.install(
        'persistence-read-failure',
      );
      final session = AppTestSession(tester, name: 'persistence-read-failure');
      await session.start();
      final original = session.project;
      final ids = await _prepareEditedProject(session);
      final before = original.toJson();
      final corrupt = File(files.pathFor('corrupt.anthem'));
      await corrupt.writeAsBytes([12, 34, 56]);
      for (final selectedPath in [
        files.pathFor('missing.anthem'),
        corrupt.path,
      ]) {
        files.selectedOpenPath = selectedPath;
        expect(await session.openProjectFromFile(), isNull);
        await tester.pump();
        expect(find.text('Could not open project'), findsOneWidget);
        expect(
          find.textContaining(
            selectedPath == corrupt.path
                ? 'may be damaged'
                : 'Check that the file',
            findRichText: true,
          ),
          findsOneWidget,
        );
        _expectSameOpenProject(session, original);
        expect(original.toJson(), before);
        expect(original.filePath, isNull);
        expect(original.isDirty, isTrue);
        ServiceRegistry.dialogController.closeDialog();
        await tester.pump();
      }
      expect(await corrupt.readAsBytes(), [12, 34, 56]);
      expect(files.openCount, 2);
      await _verifyContent(
        session,
        trackId: ids.trackId,
        patternId: ids.patternId,
        noteId: ids.noteId,
      );
      await session.dispose();
    },
  );
}
