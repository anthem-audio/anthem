/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';

mixin ProjectModelGetterMixin on AnthemModelBase {
  ProjectModel? _project;

  /// Gets the project that contains this model.
  ///
  /// This is not safe to use on models that have been removed from the tree.
  /// For example, if you remove a clip from the clip map, it is not safe to use
  /// this getter on that object.
  ProjectModel get project {
    if (_project != null) {
      return _project!;
    }

    var model = parent;
    while (model != null) {
      if (model is ProjectModel) {
        _project = model;
        return model;
      }

      model = model.parent;
    }

    throw StateError(
      'ProjectModelGetterMixin: Could not find project model. '
      'This model may be detached from the tree.',
    );
  }
}
