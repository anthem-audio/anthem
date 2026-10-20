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

import 'dart:io';

import 'package:anthem/logic/application_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _DocumentsPathProvider extends PathProviderPlatform {
  String? documentsDirectory;
  int requests = 0;

  _DocumentsPathProvider(this.documentsDirectory);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    requests++;
    return documentsDirectory;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late _DocumentsPathProvider paths;
  late SharedPreferencesAsync preferences;
  late ApplicationSettings settings;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('anthem_settings_');
    final originalPaths = PathProviderPlatform.instance;
    final originalPreferences = SharedPreferencesAsyncPlatform.instance;
    paths = _DocumentsPathProvider(path.join(temporary.path, 'Documents Ω'));
    PathProviderPlatform.instance = paths;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    settings = ApplicationSettings(preferences);

    addTearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      SharedPreferencesAsyncPlatform.instance = originalPreferences;
      await temporary.delete(recursive: true);
    });
  });

  test('default follows the system Documents location without creating directories', () async {
    expect(
      await settings.projectsDirectory,
      path.join(paths.documentsDirectory!, 'Anthem', 'Projects'),
    );
    expect(await settings.projectsDirectoryOverride, isNull);
    expect(await preferences.getAll(), isEmpty);
    expect(await temporary.list().toList(), isEmpty);
  });

  test('a directory override persists across settings instances without a Documents lookup', () async {
    final directory = path.join(temporary.path, 'Music projects');
    await settings.setProjectsDirectoryOverride(
      path.join(directory, 'unused', '..'),
    );

    final reopened = ApplicationSettings(SharedPreferencesAsync());
    expect(await reopened.projectsDirectoryOverride, directory);
    expect(await reopened.projectsDirectory, directory);
    expect(paths.requests, 0);
    expect(
      await reopened.defaultProjectsDirectory,
      path.join(paths.documentsDirectory!, 'Anthem', 'Projects'),
    );
    expect(await reopened.projectsDirectoryOverride, directory);
    expect(await temporary.list().toList(), isEmpty);
  });

  test('clearing an override restores the current platform default and preserves other settings', () async {
    await preferences.setInt('render.sampleRate', 48000);
    await settings.setProjectsDirectoryOverride(
      path.join(temporary.path, 'Custom'),
    );
    await settings.setProjectsDirectoryOverride(null);
    paths.documentsDirectory = path.join(temporary.path, 'Relocated documents');

    expect(await settings.projectsDirectoryOverride, isNull);
    expect(
      await settings.projectsDirectory,
      path.join(paths.documentsDirectory!, 'Anthem', 'Projects'),
    );
    expect(await preferences.getAll(), {'render.sampleRate': 48000});
    expect(await temporary.list().toList(), isEmpty);
  });

  test('invalid overrides preserve the configured directory', () async {
    final directory = path.join(temporary.path, 'Custom');
    await settings.setProjectsDirectoryOverride(directory);

    for (final invalid in ['', ' ', 'relative/projects']) {
      await expectLater(
        settings.setProjectsDirectoryOverride(invalid),
        throwsArgumentError,
      );
    }

    expect(await settings.projectsDirectory, directory);
  });

  test('an unavailable Documents directory leaves the default unset but allows an override', () async {
    paths.documentsDirectory = null;
    expect(await settings.projectsDirectory, isNull);

    final directory = path.join(temporary.path, 'Custom');
    await settings.setProjectsDirectoryOverride(directory);
    expect(await settings.projectsDirectory, directory);
    expect(paths.requests, 1);
  });
}
