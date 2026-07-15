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

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migration.dart';
import 'package:anthem/logic/project_file/version.dart';

const prealpha2ProjectFileMigration = ProjectFileMigration(
  targetVersion: ProjectFileVersion(
    major: 0,
    minor: 0,
    bugfix: 0,
    extra: 'prealpha.2',
  ),
  migrate: _migrateToPrealpha2,
);

void _migrateToPrealpha2(ProjectJson projectJson) {
  final sequenceValue = projectJson['sequence'];
  if (sequenceValue is! Map<String, dynamic>) {
    throw const FormatException('Expected sequence to be a JSON object.');
  }

  final arrangementsValue = sequenceValue['arrangements'];
  if (arrangementsValue is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected sequence.arrangements to be a JSON object.',
    );
  }

  if (arrangementsValue.length > 1) {
    throw MultipleArrangementsProjectFileException(
      arrangementCount: arrangementsValue.length,
    );
  }

  if (arrangementsValue.isEmpty) {
    throw const FormatException(
      'Expected the project to contain one arrangement, but found none.',
    );
  }

  final arrangementValue = arrangementsValue.values.single;
  if (arrangementValue is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected the arrangement to be a JSON object.',
    );
  }

  sequenceValue['arrangement'] = arrangementValue;
  sequenceValue.remove('arrangements');
  sequenceValue.remove('arrangementOrder');
}
