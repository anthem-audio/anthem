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

import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/project.dart';

/// Captures the current state of initialized processors in [nodes].
///
/// Returns null when no capture is needed, so commands can remain synchronous.
Future<void>? captureLiveProcessorStates(
  ProjectModel project,
  Iterable<NodeModel> nodes,
) {
  if (!project.engine.isRunning) return null;
  final captures = [
    for (final node in nodes)
      if (node.processor != null &&
          node.initializationState == NodeInitializationState.ready)
        node.updateStateFromEngine(),
  ];
  if (captures.isEmpty) return null;
  return Future.wait(captures).then((_) {});
}
