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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:meta/meta.dart';

class TrackDescriptorForCommand {
  int? index;
  final bool isSendTrack;
  final TrackType trackType;
  final Id? parentTrackId;

  TrackDescriptorForCommand({
    this.index,
    required this.isSendTrack,
    required this.trackType,
    this.parentTrackId,
  });
}

class _InternalTrackAddRemoveDescriptor {
  /// The index within the parent's child list (or top-level order list) at
  /// which to insert/remove this track.
  int? index;

  /// Whether this track belongs to the send track hierarchy.
  final bool isSendTrack;

  /// The parent track ID, or null if this track is at the top level.
  final Id? parentTrackId;

  /// The primary track model for this descriptor.
  final TrackModel trackModel;

  /// All descendant track models that should also be added to / removed from
  /// the track map. This list does NOT include [trackModel] itself.
  final List<TrackModel> descendantTrackModels;

  _InternalTrackAddRemoveDescriptor({
    this.index,
    required this.isSendTrack,
    this.parentTrackId,
    required this.trackModel,
    this.descendantTrackModels = const [],
  });
}

class TrackAddRemoveCommand extends Command {
  final bool _isAdd;

  late final List<_InternalTrackAddRemoveDescriptor> _tracks;
  RemovedNodesSnapshot? _removedNodesSnapshot;

  TrackAddRemoveCommand.add({
    required ProjectModel project,
    required List<TrackDescriptorForCommand> tracks,
  }) : _isAdd = true {
    final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;

    _tracks = tracks.map((track) {
      // Validate parent track if specified
      if (track.parentTrackId != null) {
        final parentTrack = project.tracks[track.parentTrackId];
        if (parentTrack == null) {
          throw StateError(
            'TrackAddRemoveCommand.add(): Parent track '
            '${track.parentTrackId} not found.',
          );
        }
        if (parentTrack.type != TrackType.group) {
          throw StateError(
            'TrackAddRemoveCommand.add(): Parent track '
            '${track.parentTrackId} is not a group track.',
          );
        }
      }

      return _InternalTrackAddRemoveDescriptor(
        index: track.index,
        isSendTrack: track.isSendTrack,
        parentTrackId: track.parentTrackId,
        trackModel: TrackModel(
          idAllocator: idAllocator,
          name: track.isSendTrack
              ? 'Send Track ${project.sendTrackOrder.length}'
              : 'Track ${project.trackOrder.length + 1}',
          color: AnthemColor.randomHue(),
          type: track.trackType,
        ),
      );
    }).toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
  }

  TrackAddRemoveCommand.remove({
    required ProjectModel project,
    required Iterable<Id> ids,
  }) : _isAdd = false {
    final idSet = ids.toSet();

    // Filter out IDs whose ancestors are already in the set, since removing
    // an ancestor implicitly removes all descendants.
    bool hasAncestorInSet(Id trackId) {
      var current = project.tracks[trackId];
      if (current == null) return false;
      var parentId = current.parentTrackId;
      int safetyCounter = 0;
      while (parentId != null && safetyCounter < 100000) {
        if (idSet.contains(parentId)) return true;
        final parentTrack = project.tracks[parentId];
        if (parentTrack == null) break;
        parentId = parentTrack.parentTrackId;
        safetyCounter++;
      }
      return false;
    }

    // Collect all descendants of a track (recursively)
    List<TrackModel> collectDescendants(TrackModel track) {
      final result = <TrackModel>[];
      for (final childId in track.childTracks) {
        final child = project.tracks[childId];
        if (child != null) {
          result.add(child);
          result.addAll(collectDescendants(child));
        }
      }
      return result;
    }

    final rootIds = idSet.where((id) => !hasAncestorInSet(id)).toList();

    _tracks = rootIds.map((trackId) {
      final trackModel = project.tracks[trackId];
      if (trackModel == null) {
        throw StateError(
          'TrackAddRemoveCommand.remove(): Track $trackId not found.',
        );
      }

      if (trackModel.isMasterTrack) {
        throw StateError(
          'Tried to delete the master track, which is not allowed.',
        );
      }

      final serviceRegistry = ServiceRegistry.forProject(project.id);
      final projectController = serviceRegistry.projectController;
      final isSendTrack = projectController.isSendTrack(trackId);

      final parentId = trackModel.parentTrackId;

      int index;
      if (parentId != null) {
        final parentTrack = project.tracks[parentId]!;
        index = parentTrack.childTracks.indexOf(trackId);
      } else {
        if (isSendTrack) {
          index = project.sendTrackOrder.indexOf(trackId);
        } else {
          index = project.trackOrder.indexOf(trackId);
        }
      }

      if (index == -1) {
        throw StateError(
          'TrackAddRemoveCommand.remove(): Could not find track $trackId in '
          'its parent or top-level track order.',
        );
      }

      return _InternalTrackAddRemoveDescriptor(
        index: index,
        isSendTrack: isSendTrack,
        parentTrackId: parentId,
        trackModel: trackModel,
        descendantTrackModels: collectDescendants(trackModel),
      );
    }).toList()..sort((a, b) => a.index!.compareTo(b.index!));
  }

  @override
  void execute(ProjectModel project) {
    if (_isAdd) {
      _add(project);
    } else {
      _remove(project);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (_isAdd) {
      _remove(project);
    } else {
      _add(project);
    }
  }

  void _add(ProjectModel project) {
    for (final trackDescriptor in _tracks) {
      final _InternalTrackAddRemoveDescriptor(
        index: index,
        trackModel: track,
        isSendTrack: isSendTrack,
        parentTrackId: parentTrackId,
        descendantTrackModels: descendants,
      ) = trackDescriptor;

      if (project.tracks[track.id] != null) {
        throw StateError(
          'Tried to add a track that already exists. This indicates bad usage of '
          'TrackAddRemoveCommand, or bad project state.',
        );
      }

      if (parentTrackId != null) {
        // Add to parent group track's child list
        final parentTrack = project.tracks[parentTrackId]!;
        if (index == null) {
          parentTrack.childTracks.add(track.id);
        } else {
          parentTrack.childTracks.insert(index, track.id);
        }
        track.parentTrackId = parentTrackId;
      } else {
        // Add to top-level order list
        var orderListToModify = isSendTrack
            ? project.sendTrackOrder
            : project.trackOrder;

        if (index == null) {
          orderListToModify.add(track.id);
        } else {
          orderListToModify.insert(index, track.id);
        }
        track.parentTrackId = null;
      }

      project.tracks[track.id] = track;

      // Also restore all descendants into the track map
      for (final descendant in descendants) {
        project.tracks[descendant.id] = descendant;
        ServiceRegistry.forProject(
          project.id,
        ).arrangerViewModel.registerTrack(descendant.id);
      }

      ServiceRegistry.forProject(
        project.id,
      ).arrangerViewModel.registerTrack(track.id);
    }

    if (_removedNodesSnapshot != null && !_removedNodesSnapshot!.isEmpty) {
      project.processingGraph.restoreRemovedNodesSnapshot(
        _removedNodesSnapshot!,
      );
    } else if (_isAdd) {
      final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;

      for (final trackDescriptor in _tracks) {
        final tracksToCheck = <TrackModel>[
          trackDescriptor.trackModel,
          ...trackDescriptor.descendantTrackModels,
        ];

        for (final track in tracksToCheck) {
          final gainNodeId = _tryGetTrackGainNodeId(track);
          final balanceNodeId = _tryGetTrackBalanceNodeId(track);

          final hasNoTrackNodes = gainNodeId == null && balanceNodeId == null;
          final hasSomeTrackNodes = gainNodeId != null || balanceNodeId != null;
          final hasAllTrackNodes = gainNodeId != null && balanceNodeId != null;

          if (hasNoTrackNodes) {
            track.createAndRegisterNodes(project, idAllocator);
          } else if (hasSomeTrackNodes && !hasAllTrackNodes) {
            throw StateError(
              'TrackAddRemoveCommand._add(): Track ${track.id} has incomplete '
              'node state. Both gainNodeId and balanceNodeId are required.',
            );
          }
        }
      }
    }

    final arrangerViewModel = ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel;

    arrangerViewModel.selectedTracks
      ..clear()
      ..addAll(_tracks.map((t) => t.trackModel.id));

    project.engine.processingGraphApi.compile();
  }

  void _remove(ProjectModel project) {
    final removedTrackIds = <Id>{};

    for (final trackDescriptor in _tracks.reversed) {
      final _InternalTrackAddRemoveDescriptor(
        index: index,
        trackModel: track,
        isSendTrack: isSendTrack,
        parentTrackId: parentTrackId,
        descendantTrackModels: descendants,
      ) = trackDescriptor;

      if (project.tracks[track.id] == null) {
        throw StateError(
          'Tried to remove a track that does not exist. This indicates bad usage '
          'of TrackAddRemoveCommand, or bad project state.',
        );
      }

      // Unregister and remove all descendants from the track map
      for (final descendant in descendants) {
        ServiceRegistry.forProject(
          project.id,
        ).arrangerViewModel.unregisterTrack(descendant.id);
        removedTrackIds.add(descendant.id);
        project.tracks.remove(descendant.id);
      }

      ServiceRegistry.forProject(
        project.id,
      ).arrangerViewModel.unregisterTrack(track.id);

      if (parentTrackId != null) {
        // Remove from parent group track's child list
        project.tracks[parentTrackId]!.childTracks.remove(track.id);
      } else {
        // Remove from top-level order list
        if (isSendTrack) {
          project.sendTrackOrder.remove(track.id);
        } else {
          project.trackOrder.remove(track.id);
        }
      }

      removedTrackIds.add(track.id);
      project.tracks.remove(track.id);
    }

    final arrangerViewModel = ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel;

    arrangerViewModel.selectedTracks.removeAll(
      _tracks.map((t) => t.trackModel.id),
    );

    final nodeIdsToRemove = _collectTrackNodeIdsForDescriptors(_tracks);
    if (nodeIdsToRemove.isNotEmpty) {
      final removedNodesSnapshot = project.processingGraph
          .removeNodesAndCapture(nodeIdsToRemove);
      _removedNodesSnapshot ??= removedNodesSnapshot;
    }

    if (project.engine.isRunning) {
      for (final trackId in removedTrackIds) {
        project.engine.sequencerApi.cleanUpTrack(trackId);
      }
    }

    project.engine.processingGraphApi.compile();
  }
}

Id? _tryGetTrackGainNodeId(TrackModel track) {
  return track.gainNodeId;
}

Id? _tryGetTrackBalanceNodeId(TrackModel track) {
  return track.balanceNodeId;
}

Set<Id> _collectTrackNodeIdsForDescriptors(
  Iterable<_InternalTrackAddRemoveDescriptor> descriptors,
) {
  final nodeIds = <Id>{};

  for (final descriptor in descriptors) {
    final tracksToScan = <TrackModel>[
      descriptor.trackModel,
      ...descriptor.descendantTrackModels,
    ];

    for (final track in tracksToScan) {
      nodeIds.addAll(track.getOwnedNodeIds());
    }
  }

  return nodeIds;
}

class SetTrackInstrumentNodeCommand extends Command {
  final Id trackId;
  final NodeModel instrumentNode;

  final Id? _previousInstrumentNodeId;

  RemovedNodesSnapshot? _removedAddedInstrumentSnapshot;
  RemovedNodesSnapshot? _removedPreviousInstrumentSnapshot;

  SetTrackInstrumentNodeCommand({
    required TrackModel track,
    required this.instrumentNode,
  }) : trackId = track.id,
       _previousInstrumentNodeId = track.instrumentNodeId;

  @override
  void execute(ProjectModel project) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'SetTrackInstrumentNodeCommand.execute(): Track $trackId not found.',
      );
    }

    final sequenceNoteProviderNode = _getExistingSequenceNoteProviderNode(
      project,
      track,
    );
    final liveEventProviderNode = _getExistingLiveEventProviderNode(
      project,
      track,
    );

    final hasRestorableInstrumentSnapshot =
        _removedAddedInstrumentSnapshot != null &&
        !_removedAddedInstrumentSnapshot!.isEmpty;

    if (hasRestorableInstrumentSnapshot) {
      _removeCurrentInstrumentNode(project, track, captureForRollback: false);
      project.processingGraph.restoreRemovedNodesSnapshot(
        _removedAddedInstrumentSnapshot!,
      );
    } else {
      _removeCurrentInstrumentNode(project, track, captureForRollback: true);

      project.processingGraph.addNode(instrumentNode);

      _connectInstrumentAudioToTrackGain(project, track, instrumentNode);
      _connectSequenceProviderToInstrument(
        project,
        sequenceNoteProviderNode,
        instrumentNode,
      );
      _connectLiveEventProviderToInstrument(
        project,
        liveEventProviderNode,
        instrumentNode,
      );
    }

    track.instrumentNodeId = instrumentNode.id;

    project.engine.processingGraphApi.compile();
  }

  @override
  void rollback(ProjectModel project) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'SetTrackInstrumentNodeCommand.rollback(): Track $trackId not found.',
      );
    }

    if (track.instrumentNodeId == instrumentNode.id) {
      final removedNodesSnapshot = project.processingGraph
          .removeNodesAndCapture([instrumentNode.id]);
      _removedAddedInstrumentSnapshot ??= removedNodesSnapshot;
    }

    if (_removedPreviousInstrumentSnapshot != null &&
        !_removedPreviousInstrumentSnapshot!.isEmpty) {
      project.processingGraph.restoreRemovedNodesSnapshot(
        _removedPreviousInstrumentSnapshot!,
      );
    }

    track.instrumentNodeId = _previousInstrumentNodeId;

    project.engine.processingGraphApi.compile();
  }

  void _removeCurrentInstrumentNode(
    ProjectModel project,
    TrackModel track, {
    required bool captureForRollback,
  }) {
    final currentInstrumentNodeId = track.instrumentNodeId;
    if (currentInstrumentNodeId == null ||
        currentInstrumentNodeId == instrumentNode.id) {
      return;
    }

    final removedNodesSnapshot = project.processingGraph.removeNodesAndCapture([
      currentInstrumentNodeId,
    ]);

    if (captureForRollback) {
      _removedPreviousInstrumentSnapshot ??= removedNodesSnapshot;
    }

    track.instrumentNodeId = null;
  }
}

NodeModel _getExistingSequenceNoteProviderNode(
  ProjectModel project,
  TrackModel track,
) {
  final sequenceProviderNodeId = track.sequenceNoteProviderNodeId;
  final sequenceProviderNode =
      project.processingGraph.nodes[sequenceProviderNodeId];

  if (sequenceProviderNode == null) {
    throw StateError(
      'SetTrackInstrumentNodeCommand requires an existing sequence note '
      'provider node on track ${track.id}.',
    );
  }

  return sequenceProviderNode;
}

NodeModel _getExistingLiveEventProviderNode(
  ProjectModel project,
  TrackModel track,
) {
  final liveEventProviderNodeId = track.liveEventProviderNodeId;
  final liveEventProviderNode =
      project.processingGraph.nodes[liveEventProviderNodeId];

  if (liveEventProviderNode == null) {
    throw StateError(
      'SetTrackInstrumentNodeCommand requires an existing live event '
      'provider node on track ${track.id}.',
    );
  }

  return liveEventProviderNode;
}

void _connectInstrumentAudioToTrackGain(
  ProjectModel project,
  TrackModel track,
  NodeModel instrumentNode,
) {
  if (instrumentNode.audioOutputPorts.isEmpty) {
    return;
  }

  final gainNodeId = _tryGetTrackGainNodeId(track);
  if (gainNodeId == null) {
    return;
  }

  final gainNode = project.processingGraph.nodes[gainNodeId];
  if (gainNode == null || gainNode.audioInputPorts.isEmpty) {
    return;
  }

  final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;
  project.processingGraph.addConnection(
    NodeConnectionModel(
      idAllocator: idAllocator,
      sourceNodeId: instrumentNode.id,
      sourcePortId: instrumentNode.audioOutputPorts.first.id,
      destinationNodeId: gainNode.id,
      destinationPortId: GainProcessorModel.audioInputPortId,
    ),
  );
}

void _connectSequenceProviderToInstrument(
  ProjectModel project,
  NodeModel sequenceProviderNode,
  NodeModel instrumentNode,
) {
  if (sequenceProviderNode.eventOutputPorts.isEmpty ||
      instrumentNode.eventInputPorts.isEmpty) {
    return;
  }

  final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;
  project.processingGraph.addConnection(
    NodeConnectionModel(
      idAllocator: idAllocator,
      sourceNodeId: sequenceProviderNode.id,
      sourcePortId: SequenceNoteProviderProcessorModel.eventOutputPortId,
      destinationNodeId: instrumentNode.id,
      destinationPortId: instrumentNode.eventInputPorts.first.id,
    ),
  );
}

void _connectLiveEventProviderToInstrument(
  ProjectModel project,
  NodeModel liveEventProviderNode,
  NodeModel instrumentNode,
) {
  if (liveEventProviderNode.eventOutputPorts.isEmpty ||
      instrumentNode.eventInputPorts.isEmpty) {
    return;
  }

  final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;
  project.processingGraph.addConnection(
    NodeConnectionModel(
      idAllocator: idAllocator,
      sourceNodeId: liveEventProviderNode.id,
      sourcePortId: LiveEventProviderProcessorModel.eventOutputPortId,
      destinationNodeId: instrumentNode.id,
      destinationPortId: instrumentNode.eventInputPorts.first.id,
    ),
  );
}

class TrackGroupUngroupCommand extends Command {
  /// Whether this is a group operation, or an ungroup.
  ///
  /// If this is a group operation, [_isGroup] will be true and [execute()] will
  /// create the group while [rollback()] will revert. If this is an ungroup
  /// operation, [execute()] will un-create the group and [rollback()] will
  /// create it.
  final bool _isGroup;

  /// Whether this group track should be added to the normal track list or the
  /// send track list.
  ///
  /// Only applicable if [_parentTrack] is null.
  late final bool _isForSendTrack;

  /// The group track to be added, which will become the parent of
  /// [_childrenToAddToGroup].
  late final TrackModel _newGroupTrack;

  /// The track that should be the parent of [_newGroupTrack].
  ///
  /// If null, then the track will be put in either [ProjectModel.trackOrder] or
  /// [ProjectModel.sendTrackOrder].
  late final Id? _parentTrack;

  /// The index within the parent track list at which to insert this track.
  late final int _indexInParent;

  /// The child tracks that should be added to this track.
  ///
  /// The second field in the tuple is the original index of this track, so the
  /// operation can be reversed correctly.
  late final List<(Id, int)> _childrenToAddToGroup;

  /// Creates a command to group the incoming track IDs.
  ///
  /// See the implementation for details on the exact rules for grouping. The
  /// incoming [trackIds] are the tracks selected by the user when the group
  /// action is invoked.
  TrackGroupUngroupCommand.group({
    required ProjectModel project,
    required Iterable<Id> trackIds,
  }) : _isGroup = true {
    // The logic here is non-trivial and represents intentional design
    // decisions, so I will spend some time to describe what's going on and why.
    //
    // The incoming list of track IDs are tracks that were selected when the
    // user invoked the group tracks action (e.g. via right click menu). The
    // actual behavior is more complex than just shoving them all in a single
    // group. We need to determine the actual group configuration that we want
    // for this command, and store fields which describe that behavior.
    //
    // For example, let's say we have the following track configuration:
    //
    // - A
    //   - B
    //   - C
    //   - D
    // - E
    //   - F
    //
    // Any of these tracks could be selected when this action is invoked. For
    // some of these selections, it is clear what should happen. For example, if
    // B and C are selected, then this is the clear result:
    //
    // - A
    //   - NEW GROUP TRACK
    //     - B
    //     - C
    //   - D
    // - E
    //   - F
    //
    // Other selections are less obvious, but we could use reasonable
    // assumptions to determine what happens. For example, if A and E are
    // selected but not B, C, D, or F, you might still expect:
    //
    // - NEW GROUP TRACK
    //   - A
    //     - B
    //     - C
    //     - D
    //   - E
    //     - F
    //
    // However, say you have only tracks B and E selected. At that point it is
    // far less obvious what should happen.
    //
    // What we actually do in any given scenario is the following:
    //
    // 1. Find the common ancestor of all tracks in the incoming list
    // 2. Within the children of that common ancestor (or the top-level tracks
    //    if there is no common ancestor), make a list of all tracks that are or
    //    contain items in the incoming list
    // 3. Remove these tracks from their parent, and add them to a new group
    //    track within that parent
    //
    // This is simple, correctly handles the cases above, and produces behavior
    // that is predictable.

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final projectController = serviceRegistry.projectController;
    final idAllocator = serviceRegistry.idAllocator;

    if (!projectController.canGroupTracks(trackIds)) {
      throw StateError(
        'TrackGroupUngroupCommand.group(): Invalid track list for grouping. '
        'canGroupTracks(trackIds) returned false.',
      );
    }

    if (trackIds.isEmpty) {
      throw StateError(
        'TrackGroupUngroupCommand.group(): Track list cannot be empty.',
      );
    }

    _isForSendTrack = projectController.isSendTrack(trackIds.first);

    /// Gets the nearest common ancestor of all tracks, if there is any.
    ///
    /// Given the following tracks:
    /// - A
    ///   - B
    ///     - C
    ///     - D
    ///   - E
    ///   - F
    /// - G
    ///   - H
    ///
    /// Returns the common ancestor, as the first item in the tuple:
    ///
    /// If C and D are passed in, B will be returned as the common ancestor. If
    /// C and E are passed in, A will be returned. If B and H are passed in,
    /// null will be returned.
    ///
    /// Returns a list of immediate children that were passed through when
    /// reaching the common ancestor, as the second item in the tuple:
    ///
    /// If C and E are passed in, the common ancestor will be A, and the
    /// children passed through will be B and E, both immediate children of A. F
    /// will not be given, since it is not a parent of any of the items passed
    /// in [originTrackList.]
    (Id? commonAncestor, List<Id> childrenPassedThrough) getCommonAncestor(
      Iterable<Id> originTrackList,
    ) {
      int getDepth(Id trackId) {
        var track = project.tracks[trackId]!;
        var depth = 0;
        // The 100,000 here is a sanity check, to prevent infinite loop in the
        // case of a cycle. Cycles should not be possible unless we have a bug,
        // or a project file that was incorrectly modified by someone else.
        while (track.parentTrackId != null && depth < 100_000) {
          depth++;
          track = project.tracks[track.parentTrackId]!;
        }
        return depth;
      }

      // This is a map of trackId to (depth, direct children passed through to
      // reach this track)
      final trackDepthMap = Map.fromEntries(
        originTrackList.map((id) => MapEntry(id, (getDepth(id), <Id>[]))),
      );

      int sanityCount = 0;

      while (true) {
        int highestDepth = 0;
        Id? trackIdAtHighest;

        for (final MapEntry(key: trackId, value: (depth, _))
            in trackDepthMap.entries) {
          if (depth > highestDepth) {
            trackIdAtHighest = trackId;
            highestDepth = depth;
          }
        }

        if (highestDepth == 0) {
          break;
        }

        final (oldDepth, _) = trackDepthMap.remove(trackIdAtHighest!)!;
        final parentTrackId = project.tracks[trackIdAtHighest]!.parentTrackId!;
        if (trackDepthMap[parentTrackId] == null) {
          trackDepthMap[parentTrackId] = (oldDepth - 1, [trackIdAtHighest]);
        } else {
          trackDepthMap[parentTrackId]!.$2.add(trackIdAtHighest);
        }

        if (trackDepthMap.length == 1) {
          break;
        }

        if (sanityCount > 100_000) {
          throw StateError(
            'Broke out of likely infinite loop in '
            'TrackGroupUngroupCommand.group().getCommonAncestor()',
          );
        }

        sanityCount++;
      }

      if (trackDepthMap.length != 1) {
        return (null, trackDepthMap.keys.toList());
      }

      final entryToReturn = trackDepthMap.entries.first;

      return (entryToReturn.key, entryToReturn.value.$2);
    }

    final (newGroupParent, tracksToAddToNewGroup) = getCommonAncestor(trackIds);

    final parentTrackList = newGroupParent != null
        ? project.tracks[newGroupParent]!.childTracks.nonObservableInner
        : _isForSendTrack
        ? project.sendTrackOrder.nonObservableInner
        : project.trackOrder.nonObservableInner;

    final tracksToAddToNewGroupIndices = Map.fromEntries(
      tracksToAddToNewGroup.map(
        (trackId) => MapEntry(trackId, parentTrackList.indexOf(trackId)),
      ),
    );

    tracksToAddToNewGroup.sort(
      (a, b) => tracksToAddToNewGroupIndices[a]!.compareTo(
        tracksToAddToNewGroupIndices[b]!,
      ),
    );

    _indexInParent = parentTrackList.indexWhere(
      (trackId) => tracksToAddToNewGroup.contains(trackId),
    );

    _newGroupTrack = TrackModel(
      idAllocator: idAllocator,
      name: 'New Group',
      color: AnthemColor.randomHue(),
      type: .group,
    );
    _parentTrack = newGroupParent;
    _childrenToAddToGroup = tracksToAddToNewGroup
        .map((t) => (t, tracksToAddToNewGroupIndices[t]!))
        .toList();
  }

  /// Ungroups the given group track by removing the group track and replacing
  /// it with its children.
  TrackGroupUngroupCommand.ungroup({
    required ProjectModel project,
    required Id groupTrack,
  }) : _isGroup = false {
    final track = project.tracks[groupTrack];
    if (track == null) {
      throw StateError(
        'TrackGroupUngroupCommand.ungroup(): Track $groupTrack not found.',
      );
    }

    if (track.type != .group) {
      throw StateError(
        'TrackGroupUngroupCommand.ungroup(): Track $groupTrack is not a group '
        'track.',
      );
    }

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final projectController = serviceRegistry.projectController;

    _isForSendTrack = projectController.isSendTrack(groupTrack);
    _newGroupTrack = track;
    _parentTrack = track.parentTrackId;

    final parentTrackList = _parentTrack != null
        ? project.tracks[_parentTrack]!.childTracks.nonObservableInner
        : _isForSendTrack
        ? project.sendTrackOrder.nonObservableInner
        : project.trackOrder.nonObservableInner;

    _indexInParent = parentTrackList.indexOf(groupTrack);

    // After the group track is removed from the parent list, each child should
    // be inserted starting at the group track's former index.
    _childrenToAddToGroup = [];
    for (var i = 0; i < track.childTracks.length; i++) {
      _childrenToAddToGroup.add((track.childTracks[i], _indexInParent + i));
    }
  }

  @override
  void execute(ProjectModel project) {
    if (_isGroup) {
      _group(project);
    } else {
      _ungroup(project);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (_isGroup) {
      _ungroup(project);
    } else {
      _group(project);
    }
  }

  void _group(ProjectModel project) {
    final parentTrackList = _parentTrack != null
        ? project.tracks[_parentTrack]!.childTracks
        : _isForSendTrack
        ? project.sendTrackOrder
        : project.trackOrder;

    for (final (trackId, _) in _childrenToAddToGroup) {
      parentTrackList.remove(trackId);
    }

    _newGroupTrack.childTracks
      ..clear()
      ..addAll(_childrenToAddToGroup.map((c) => c.$1));

    project.tracks[_newGroupTrack.id] = _newGroupTrack;

    parentTrackList.insert(_indexInParent, _newGroupTrack.id);

    updateTrackParents(project, project.tracks[_parentTrack]);

    ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel.registerTrack(_newGroupTrack.id);
  }

  void _ungroup(ProjectModel project) {
    final parentTrackList = _parentTrack != null
        ? project.tracks[_parentTrack]!.childTracks
        : _isForSendTrack
        ? project.sendTrackOrder
        : project.trackOrder;

    project.tracks.remove(_newGroupTrack.id);
    parentTrackList.remove(_newGroupTrack.id);

    _newGroupTrack.childTracks.clear();

    for (final (trackId, originalIndex) in _childrenToAddToGroup) {
      parentTrackList.insert(originalIndex, trackId);
    }

    updateTrackParents(project, project.tracks[_parentTrack]);

    ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel.unregisterTrack(_newGroupTrack.id);
  }
}

/// Updates the parentTrackId field for all children of [track].
///
/// If [track] is null, this will update all tracks in the project.
@visibleForTesting
void updateTrackParents(ProjectModel project, [TrackModel? track]) {
  if (track == null) {
    for (final trackId in project.trackOrder.nonObservableInner.followedBy(
      project.sendTrackOrder.nonObservableInner,
    )) {
      final childTrack = project.tracks[trackId]!;
      childTrack.parentTrackId = null;
      updateTrackParents(project, childTrack);
    }

    return;
  }

  if (track.type != .group) return;

  for (final childTrackId in track.childTracks.nonObservableInner) {
    final childTrack = project.tracks[childTrackId]!;
    childTrack.parentTrackId = track.id;
    updateTrackParents(project, childTrack);
  }
}

class SetTrackNameCommand extends Command {
  final Id trackId;
  final String newName;
  final String oldName;

  SetTrackNameCommand({required TrackModel track, required this.newName})
    : trackId = track.id,
      oldName = track.name;

  @override
  void execute(ProjectModel project) {
    project.tracks[trackId]!.name = newName;
  }

  @override
  void rollback(ProjectModel project) {
    project.tracks[trackId]!.name = oldName;
  }
}

class SetTrackColorCommand extends Command {
  final Id trackId;
  final double newHue;
  final double oldHue;
  final AnthemColorPaletteKind newPalette;
  final AnthemColorPaletteKind oldPalette;

  SetTrackColorCommand({
    required TrackModel track,
    required this.newHue,
    required this.newPalette,
  }) : trackId = track.id,
       oldHue = track.color.hue,
       oldPalette = track.color.palette;

  @override
  void execute(ProjectModel project) {
    project.tracks[trackId]!.color.hue = newHue;
    project.tracks[trackId]!.color.palette = newPalette;
  }

  @override
  void rollback(ProjectModel project) {
    project.tracks[trackId]!.color.hue = oldHue;
    project.tracks[trackId]!.color.palette = oldPalette;
  }
}
