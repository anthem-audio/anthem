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

import '../../bin/integration_test/test_plugin_manifest.dart';
import 'app_test_session.dart';
import 'temporary_project_file_selector.dart';
import 'waits.dart';

const _manifestPath = String.fromEnvironment('ANTHEM_TEST_PLUGIN_MANIFEST');

TestPluginManifest loadTestPlugins() {
  if (_manifestPath.isEmpty) {
    throw StateError(
      'Use the integration-test runner to build or select test plugins.',
    );
  }
  return TestPluginManifest.read(File(_manifestPath));
}

/// Supplies a processing configuration without opening a hardware audio device.
/// Loading, preparation, port discovery, and graph publication remain real.
Future<void> startOfflinePluginProcessing(AppTestSession session) async {
  final configuration = await waitForFuture(
    session.tester,
    session.project.engine.renderApi.startRenderAudioSession(
      sampleRate: 48000,
      blockSize: 128,
      outputChannelCount: 2,
    ),
    conditionDescription: 'offline plugin processing configuration',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    checkHealth: session.checkEngine,
  );
  await publishPluginGraph(session);
  // isAudioReady includes offline sessions; verify the selected configuration.
  expect(configuration.sampleRate, 48000);
  expect(configuration.blockSize, 128);
  expect(configuration.inputChannelCount, 0);
  expect(configuration.outputChannelCount, 2);
}

Future<void> publishPluginGraph(AppTestSession session) => waitForFuture(
  session.tester,
  session.services.projectController.publishProcessingGraph(),
  conditionDescription:
      'plugin initialization, discovered ports, and graph publication',
  collectTimeoutDiagnostics: () => session.sessionDiagnostics,
  checkHealth: session.checkEngine,
  timeout: const Duration(seconds: 45),
);

/// Replaces selection only, allowing precisely the two compiled plugin paths.
/// Project selection and temporary-file ownership use the persistence helper.
class TestPluginFileSelector extends FileSelectorPlatform {
  final TemporaryProjectFileSelector projectFiles;
  final TestPluginManifest fixtures;
  String? selectedPluginPath;
  int pluginSelectionCount = 0;

  TestPluginFileSelector._(this.projectFiles, this.fixtures);

  static Future<TestPluginFileSelector> install(
    String name,
    TestPluginManifest fixtures,
  ) async {
    final projectFiles = await TemporaryProjectFileSelector.install(name);
    final selector = TestPluginFileSelector._(projectFiles, fixtures);
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = projectFiles);
    return selector;
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    if (acceptedTypeGroups?.single.extensions?.single == 'vst3') {
      pluginSelectionCount++;
      expect(confirmButtonText, 'Choose plugin');
      final selected = selectedPluginPath;
      if (selected == null) return null;
      if (![fixtures.instrument, fixtures.effect].contains(selected)) {
        throw StateError('Selected plugin is not a configured test fixture.');
      }
      return XFile(selected);
    }
    return projectFiles.openFile(
      acceptedTypeGroups: acceptedTypeGroups,
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
    );
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) => projectFiles.getSaveLocation(
    acceptedTypeGroups: acceptedTypeGroups,
    options: options,
  );
}
