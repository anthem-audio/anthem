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

import 'package:anthem/logic/project_file/version.dart';

sealed class ProjectFileLoadException implements Exception {
  const ProjectFileLoadException();
}

final class ProjectSavedInNewerVersionException
    extends ProjectFileLoadException {
  const ProjectSavedInNewerVersionException({
    required this.savedVersion,
    required this.currentVersion,
  });

  final ProjectFileVersion savedVersion;
  final ProjectFileVersion currentVersion;

  @override
  String toString() {
    return 'ProjectSavedInNewerVersionException: project $savedVersion, '
        'software $currentVersion';
  }
}

final class ProjectVersionTooOldException extends ProjectFileLoadException {
  const ProjectVersionTooOldException({
    required this.savedVersion,
    required this.oldestSupportedVersion,
  });

  final ProjectFileVersion savedVersion;
  final ProjectFileVersion oldestSupportedVersion;

  @override
  String toString() {
    return 'ProjectVersionTooOldException: project $savedVersion, oldest '
        'supported $oldestSupportedVersion';
  }
}

final class InvalidProjectFileException extends ProjectFileLoadException {
  const InvalidProjectFileException({
    required this.cause,
    this.causeStackTrace,
  });

  final Object cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() => 'InvalidProjectFileException: $cause';
}

final class ProjectFileReadException extends ProjectFileLoadException {
  const ProjectFileReadException({required this.cause, this.causeStackTrace});

  final Object cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() => 'ProjectFileReadException: $cause';
}

final class ProjectFileMigrationException extends ProjectFileLoadException {
  const ProjectFileMigrationException({
    required this.fromVersion,
    required this.targetVersion,
    required this.cause,
    this.causeStackTrace,
  });

  final ProjectFileVersion fromVersion;
  final ProjectFileVersion targetVersion;
  final Object cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() {
    return 'ProjectFileMigrationException: $fromVersion to $targetVersion: '
        '$cause';
  }
}

/// The project cannot be migrated because it contains more than one
/// arrangement.
final class MultipleArrangementsProjectFileException implements Exception {
  const MultipleArrangementsProjectFileException({
    required this.arrangementCount,
  });

  final int arrangementCount;

  @override
  String toString() {
    return 'MultipleArrangementsProjectFileException: $arrangementCount '
        'arrangements';
  }
}
