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
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/processing_graph_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';

/// Loads processor state, retaining both snapshots for undo and redo.
///
/// The command retains its own handle immediately; the caller may dispose
/// [snapshot] after construction. The previous state is captured on the first
/// successful execution and kept until the command leaves history.
class LoadProcessorSnapshotCommand extends Command {
  final Id nodeId;
  final ProcessorSnapshot _targetSnapshot;
  ProcessorSnapshot? _previousSnapshot;

  LoadProcessorSnapshotCommand({
    required this.nodeId,
    required ProcessorSnapshot snapshot,
  }) : _targetSnapshot = snapshot.retain();

  @override
  Future<void> execute(ProjectModel project) async {
    final graph = ServiceRegistry.forProject(project.id)
        .processingGraphController;
    if (_previousSnapshot == null) {
      _previousSnapshot = await graph.replaceSnapshot(nodeId, _targetSnapshot);
    } else {
      await graph.loadSnapshot(nodeId, _targetSnapshot);
    }
  }

  @override
  Future<void> rollback(ProjectModel project) =>
      ServiceRegistry.forProject(project.id).processingGraphController
          .loadSnapshot(nodeId, _previousSnapshot!);

  @override
  void dispose() {
    _targetSnapshot.dispose();
    _previousSnapshot?.dispose();
  }
}
