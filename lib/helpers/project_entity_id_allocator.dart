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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:meta/meta.dart';

class ProjectEntityIdAllocator {
  final ProjectModel? project;
  final Id Function()? _allocateIdOverride;

  ProjectEntityIdAllocator(this.project) : _allocateIdOverride = null;

  ProjectEntityIdAllocator.fromCallback(Id Function() allocateId)
    : project = null,
      _allocateIdOverride = allocateId;

  @visibleForTesting
  ProjectEntityIdAllocator.test(Id Function() allocateId)
    : this.fromCallback(allocateId);

  Id allocateId() {
    return _allocateIdOverride?.call() ?? project!.allocateId();
  }

  Id allocateSequenceNoteId() {
    return _allocateIdOverride?.call() ?? project!.sequence.allocateNoteId();
  }

  Id allocateSequenceClipId() {
    return _allocateIdOverride?.call() ?? project!.sequence.allocateClipId();
  }
}
