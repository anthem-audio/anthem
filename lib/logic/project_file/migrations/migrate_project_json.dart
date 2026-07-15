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

import 'package:anthem/logic/project_file/migrations/migration.dart';
import 'package:anthem/logic/project_file/migrations/registry.dart';
import 'package:anthem/logic/project_file/version.dart';

const _savedVersionKey = 'savedInSoftwareVersion';

/// Applies every project-file migration newer than the version in
/// [projectJson].
///
/// The input map is mutated and returned. Callers must discard it if a
/// migration throws.
ProjectJson migrateProjectJson(
  ProjectJson projectJson, {
  List<ProjectFileMigration> migrations = projectFileMigrations,
  ProjectFileVersion? currentVersion,
  ProjectFileVersion oldestSupportedVersion = oldestSupportedProjectFileVersion,
}) {
  final resolvedCurrentVersion = currentVersion ?? currentProjectFileVersion;

  final savedVersionValue = projectJson[_savedVersionKey];
  if (savedVersionValue is! String) {
    throw const FormatException(
      'Expected savedInSoftwareVersion to be a version string.',
    );
  }

  final savedVersion = ProjectFileVersion.parse(savedVersionValue);

  if (savedVersion == resolvedCurrentVersion) {
    return projectJson;
  }

  _validateMigrationConfiguration(
    migrations,
    currentVersion: resolvedCurrentVersion,
    oldestSupportedVersion: oldestSupportedVersion,
  );

  if (savedVersion < oldestSupportedVersion) {
    throw UnsupportedError(
      'Project file version $savedVersion is older than the oldest supported '
      'version $oldestSupportedVersion.',
    );
  }

  if (savedVersion > resolvedCurrentVersion) {
    throw UnsupportedError(
      'Project file version $savedVersion is newer than the current software '
      'version $resolvedCurrentVersion.',
    );
  }

  for (final migration in migrations) {
    if (migration.targetVersion <= savedVersion) {
      continue;
    }

    migration.migrate(projectJson);
    projectJson[_savedVersionKey] = migration.targetVersion.toString();
  }

  projectJson[_savedVersionKey] = resolvedCurrentVersion.toString();
  return projectJson;
}

void _validateMigrationConfiguration(
  List<ProjectFileMigration> migrations, {
  required ProjectFileVersion currentVersion,
  required ProjectFileVersion oldestSupportedVersion,
}) {
  if (oldestSupportedVersion > currentVersion) {
    throw StateError(
      'The oldest supported project-file version cannot be newer than the '
      'current version.',
    );
  }

  ProjectFileVersion? previousVersion;

  for (final migration in migrations) {
    if (previousVersion != null && migration.targetVersion <= previousVersion) {
      throw StateError(
        'Project-file migrations must be ordered by strictly increasing '
        'target version.',
      );
    }

    if (migration.targetVersion > currentVersion) {
      throw StateError(
        'Project-file migration ${migration.targetVersion} is newer than the '
        'current software version $currentVersion.',
      );
    }

    previousVersion = migration.targetVersion;
  }
}
