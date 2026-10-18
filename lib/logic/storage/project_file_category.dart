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

/// A directory containing one kind of project file.
///
/// [directoryName] is a single folder name relative to the project root. It is
/// part of each file's saved ID, so changing it also changes those IDs.
class ProjectFileCategory {
  final String directoryName;

  /// Whether these files can be regenerated from the project's saved data.
  ///
  /// Cache files are excluded from `ProjectFileStore.projectFileIds` and deleted
  /// when the store closes. Required project data must use a non-cache category.
  final bool isCache;

  const ProjectFileCategory(this.directoryName, {this.isCache = false});

  // Add categories as other kinds of project data are supported. For now, only
  // plugin states need a directory.
  static const pluginStates = ProjectFileCategory('plugin states');

  static const defaults = [pluginStates];
}
