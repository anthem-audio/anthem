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

import 'package:anthem/logic/application_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _NoDocumentsPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() {
    fail('Browser settings must not query native filesystem paths.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApplicationSettings settings;
  late SharedPreferencesAsync preferences;

  setUp(() {
    final originalPaths = PathProviderPlatform.instance;
    final originalPreferences = SharedPreferencesAsyncPlatform.instance;
    PathProviderPlatform.instance = _NoDocumentsPathProvider();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    settings = ApplicationSettings(preferences);
    addTearDown(() {
      PathProviderPlatform.instance = originalPaths;
      SharedPreferencesAsyncPlatform.instance = originalPreferences;
    });
  });

  test('browser settings have no native projects directory', () async {
    expect(await settings.projectsDirectory, isNull);
    await preferences.setString(
      'application.projectsDirectory',
      '/old/projects',
    );
    expect(await settings.projectsDirectory, isNull);
    await settings.setProjectsDirectoryOverride(null);
    expect(await settings.projectsDirectoryOverride, isNull);
  });

  test('browser settings reject native directory configuration without changing preferences', () async {
    await expectLater(
      settings.setProjectsDirectoryOverride('/projects'),
      throwsUnsupportedError,
    );
    expect(await preferences.getAll(), isEmpty);
  });
}
