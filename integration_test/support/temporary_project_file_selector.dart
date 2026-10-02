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

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'app_test_session.dart';

/// Replaces only native selection. The application still reads and writes files.
/// A null selected path represents cancellation. Register this before the app
/// session so teardown closes its engines before deleting the temporary files.
class TemporaryProjectFileSelector extends FileSelectorPlatform {
  final Directory directory;
  String? selectedOpenPath;
  String? selectedSavePath;
  int openCount = 0;
  int saveCount = 0;

  TemporaryProjectFileSelector._(this.directory);

  static Future<TemporaryProjectFileSelector> install(
    String scenarioName,
  ) async {
    if (configuredArtifacts.isEmpty) {
      throw StateError('Use the integration-test runner to supply artifacts.');
    }
    final parent = Directory('$configuredArtifacts/$scenarioName');
    await parent.create(recursive: true);
    final directory = await parent.createTemp('project-files-');
    final original = FileSelectorPlatform.instance;
    final selector = TemporaryProjectFileSelector._(directory);
    FileSelectorPlatform.instance = selector;
    addTearDown(() async {
      FileSelectorPlatform.instance = original;
      await directory.delete(recursive: true);
    });
    return selector;
  }

  String pathFor(String relativePath) =>
      _requireTemporaryPath(path.join(directory.path, relativePath));

  String _requireTemporaryPath(String selectedPath) {
    final normalized = path.normalize(path.absolute(selectedPath));
    if (!path.isWithin(path.absolute(directory.path), normalized)) {
      throw StateError('Selected project path is outside the test directory.');
    }
    return normalized;
  }

  void _checkProjectFilter(List<XTypeGroup>? groups) {
    expect(groups, hasLength(1));
    expect(groups!.single.extensions, ['anthem']);
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openCount++;
    _checkProjectFilter(acceptedTypeGroups);
    final selectedPath = selectedOpenPath;
    return selectedPath == null
        ? null
        : XFile(_requireTemporaryPath(selectedPath));
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saveCount++;
    _checkProjectFilter(acceptedTypeGroups);
    expect(options.suggestedName, endsWith('.anthem'));
    final selectedPath = selectedSavePath;
    return selectedPath == null
        ? null
        : FileSaveLocation(_requireTemporaryPath(selectedPath));
  }
}
