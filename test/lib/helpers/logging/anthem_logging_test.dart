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

import 'dart:convert';
import 'dart:io';

import 'package:anthem/helpers/logging/anthem_logging.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('anthem_logging_test_');
    await AnthemLogManager.instance.dispose();
  });

  tearDown(() async {
    await AnthemLogManager.instance.dispose();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<Directory> initializeLogging() async {
    await AnthemLogManager.instance.initialize(rootDirectory: tempRoot);

    final sessionPath = AnthemLogManager.instance.activeSessionDirectoryPath;
    expect(sessionPath, isNotNull);

    return Directory(sessionPath!);
  }

  Future<void> waitForCondition(Future<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));

    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    fail('Timed out waiting for condition.');
  }

  test('initialize creates a session with metadata and app log files', () async {
    final sessionDirectory = await initializeLogging();

    expect(await sessionDirectory.exists(), isTrue);
    expect(
      await File(
        '${sessionDirectory.path}${Platform.pathSeparator}metadata.json',
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        '${sessionDirectory.path}${Platform.pathSeparator}app.log',
      ).exists(),
      isTrue,
    );

    final metadata =
        jsonDecode(
              await File(
                '${sessionDirectory.path}${Platform.pathSeparator}metadata.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;

    expect(metadata['schemaVersion'], 1);
    expect(metadata['logRoot'], tempRoot.path);
    expect(metadata['processId'], pid);
  });

  test('logging package records are written to app.log as text', () async {
    final sessionDirectory = await initializeLogging();
    final logger = Logger('test.logging');

    logger.info('hello from test');
    logger.severe(
      'something failed',
      'boom',
      StackTrace.fromString('frame 1\nframe 2'),
    );
    await AnthemLogManager.instance.flush();

    final appLog = File(
      '${sessionDirectory.path}${Platform.pathSeparator}app.log',
    );
    final content = await appLog.readAsString();

    expect(content, contains('INFO'));
    expect(content, contains('SEVERE'));
    expect(content, contains('[test.logging]'));
    expect(content, contains('  hello from test'));
    expect(content, contains('  something failed'));
    expect(content, contains('  Error: boom'));
    expect(content, contains('  Stack trace:'));
    expect(content, contains('    frame 1'));
    expect(content, contains('    frame 2'));
  });

  test('child process environment contains the active session path', () async {
    final sessionDirectory = await initializeLogging();

    expect(
      AnthemLogManager.instance.childProcessEnvironment,
      containsPair(
        AnthemLogManager.engineLogSessionEnvironmentKey,
        sessionDirectory.path,
      ),
    );
  });

  test(
    'retention pruning deletes extra sessions but keeps the active session',
    () async {
      final sessionsRoot = Directory(
        '${tempRoot.path}${Platform.pathSeparator}sessions',
      );
      await sessionsRoot.create(recursive: true);

      for (var i = 0; i < 12; i++) {
        final inactiveSession = Directory(
          '${sessionsRoot.path}${Platform.pathSeparator}inactive-$i',
        );
        await inactiveSession.create();
        await File(
          '${inactiveSession.path}${Platform.pathSeparator}app.log',
        ).writeAsString('old\n');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final sessionDirectory = await initializeLogging();

      await waitForCondition(() async {
        final retainedSessions = await sessionsRoot
            .list(followLinks: false)
            .where((entity) => entity is Directory)
            .toList();

        return retainedSessions.length <= 10;
      });

      expect(await sessionDirectory.exists(), isTrue);
    },
  );

  test(
    'exportLogs writes a zip containing metadata and app log files',
    () async {
      final sessionDirectory = await initializeLogging();
      Logger('test.export').warning('export me');
      await AnthemLogManager.instance.flush();

      final outputPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'anthem_logging_export_$pid.zip';
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      addTearDown(() async {
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
      });

      final exportedPath = await AnthemLogManager.instance.exportLogs(
        outputPath: outputPath,
      );

      expect(exportedPath, outputPath);
      expect(await outputFile.exists(), isTrue);

      final archive = ZipDecoder().decodeBytes(await outputFile.readAsBytes());
      final fileNames = archive.files.map((file) => file.name).toSet();
      final sessionName = sessionDirectory.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
      );

      expect(
        fileNames,
        contains('AnthemLogs/sessions/$sessionName/metadata.json'),
      );
      expect(fileNames, contains('AnthemLogs/sessions/$sessionName/app.log'));
    },
  );
}
