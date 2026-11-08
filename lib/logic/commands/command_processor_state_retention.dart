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

import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/processing_graph/node.dart';

/// Retains processor-state assets while a command's nodes are removed.
///
/// The command performs node removal and restoration, and disposes these claims
/// when the nodes are restored or the command leaves history.
class CommandProcessorStateRetention {
  AssetRetention? _retention;
  Map<NodeModel, String> _states = {};

  /// Retains [nodes]' state files for the command before removing the nodes.
  ///
  /// Call after capturing any live plugin state. The nodes' project claims stay
  /// valid until [releaseProjectClaims] is called.
  void retainForRemoval(ProjectStorage storage, Iterable<NodeModel> nodes) {
    final states = <NodeModel, String>{};
    for (final node in nodes) {
      final retentionId = node.processorStateRetentionId;
      if (retentionId != null) {
        states[node] = storage.resolveRetention(retentionId);
      }
    }
    final retention = states.isEmpty
        ? null
        : storage.retainAssets(states.values);
    dispose();
    _retention = retention;
    _states = states;
  }

  /// Releases the removed nodes' project claims and clears their retention IDs.
  void releaseProjectClaims(ProjectStorage storage) {
    for (final node in _states.keys) {
      storage.projectFiles.releaseRetention(node.processorStateRetentionId!);
      node.processorStateRetentionId = null;
    }
  }

  /// Assigns new project claims to the nodes before they rejoin the graph.
  void restoreProjectClaims(ProjectStorage storage) {
    for (final entry in _states.entries) {
      entry.key.processorStateRetentionId = storage.projectFiles.retain(
        entry.value,
      );
    }
  }

  /// Releases the command's claims. May be called repeatedly.
  void dispose() {
    _retention?.dispose();
    _retention = null;
    _states.clear();
  }
}
