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

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent application preferences shared by all projects.
class ApplicationSettings {
  static const _projectsDirectoryKey = 'application.projectsDirectory';

  final SharedPreferencesAsync _preferences;

  ApplicationSettings(this._preferences);

  /// The configured projects directory, or null when using the platform default.
  Future<String?> get projectsDirectoryOverride =>
      _preferences.getString(_projectsDirectoryKey);

  /// The preferred parent directory for new projects.
  ///
  /// Defaults to `Anthem/Projects` under the system Documents directory.
  /// Returns null on web or when the system Documents location is unavailable.
  /// Reading this setting does not create directories.
  Future<String?> get projectsDirectory async {
    if (kIsWeb) return null;

    final override = await projectsDirectoryOverride;
    if (override != null) return override;

    try {
      final documents = await getApplicationDocumentsDirectory();
      return path.join(documents.path, 'Anthem', 'Projects');
    } on MissingPlatformDirectoryException {
      return null;
    }
  }

  /// Saves an absolute directory override, or clears it when [directory] is null.
  ///
  /// The directory need not exist. Setting it does not create it.
  /// Throws [ArgumentError] for a relative path and [UnsupportedError] when
  /// setting a directory on web.
  Future<void> setProjectsDirectoryOverride(String? directory) async {
    if (directory == null) {
      await _preferences.remove(_projectsDirectoryKey);
      return;
    }
    if (kIsWeb) {
      throw UnsupportedError(
        'Project directories are only available on desktop.',
      );
    }
    if (!path.isAbsolute(directory)) {
      throw ArgumentError.value(
        directory,
        'directory',
        'Expected an absolute path.',
      );
    }
    await _preferences.setString(
      _projectsDirectoryKey,
      path.normalize(directory),
    );
  }
}
