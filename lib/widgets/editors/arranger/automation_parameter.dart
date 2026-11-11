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
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';

/// Resolves parameter metadata for a real or temporary automation lane.
///
/// Missing targets, removed plugins, and ports without parameter metadata have
/// no known parameter. Callers can use the default visual baseline in that case.
NodePortModel? resolveAutomationParameterPort({
  required ProjectModel project,
  required Id? nodeId,
  required int? portId,
}) {
  final node = project.processingGraph.nodes[nodeId];
  if (node == null) return null;

  for (final port in node.controlInputPorts) {
    if (port.id == portId && port.config.parameterConfig != null) {
      return port;
    }
  }
  return null;
}
