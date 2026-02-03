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
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';

class TrackDescriptorForCommand {
  int? index;
  final bool isSendTrack;
  final TrackType trackType;

  TrackDescriptorForCommand({
    this.index,
    required this.isSendTrack,
    required this.trackType,
  });
}

class _InternalTrackAddRemoveDescriptor {
  int? index;
  final bool isSendTrack;
  final TrackModel trackModel;

  _InternalTrackAddRemoveDescriptor({
    this.index,
    required this.isSendTrack,
    required this.trackModel,
  });
}

class TrackAddRemoveCommand extends Command {
  final bool _isAdd;

  late final List<_InternalTrackAddRemoveDescriptor> _tracks;

  TrackAddRemoveCommand.add({
    required ProjectModel project,
    required List<TrackDescriptorForCommand> tracks,
  }) : _isAdd = true {
    _tracks = tracks.map((track) {
      return _InternalTrackAddRemoveDescriptor(
        index: track.index,
        isSendTrack: track.isSendTrack,
        trackModel: TrackModel(
          name: track.isSendTrack
              ? 'Send Track ${project.sendTrackOrder.length}'
              : 'Track ${project.trackOrder.length + 1}',
          color: AnthemColor.randomHue(),
          type: track.trackType,
        ),
      );
    }).toList()..sort((a, b) => a.index!.compareTo(b.index!));
  }

  TrackAddRemoveCommand.remove({
    required ProjectModel project,
    required Iterable<Id> ids,
  }) : _isAdd = false {
    _tracks = ids.map((trackId) {
      var isSendTrack = false;

      var index = project.trackOrder.indexOf(trackId);
      if (index == -1) {
        isSendTrack = true;
        index = project.sendTrackOrder.indexOf(trackId);
      }

      if (index == -1) {
        throw StateError(
          'TrackAddRemoveCommand.remove(): Could not find track in track order.',
        );
      }

      return _InternalTrackAddRemoveDescriptor(
        index: index,
        isSendTrack: isSendTrack,
        trackModel: project.tracks[trackId]!,
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
      ) = trackDescriptor;

      if (project.tracks[track.id] != null) {
        throw StateError(
          'Tried to add a track that already exists. This indicates bad usage of '
          'TrackAddRemoveCommand, or bad project state.',
        );
      }

      var orderListToModify = isSendTrack
          ? project.sendTrackOrder
          : project.trackOrder;

      if (index == null) {
        orderListToModify.add(track.id);
      } else {
        orderListToModify.insert(index, track.id);
      }

      project.tracks[track.id] = track;

      ServiceRegistry.forProject(
        project.id,
      ).arrangerViewModel.registerTrack(track.id);
    }

    final arrangerViewModel = ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel;

    arrangerViewModel.selectedTracks
      ..clear()
      ..addAll(_tracks.map((t) => t.trackModel.id));
  }

  void _remove(ProjectModel project) {
    for (final trackDescriptor in _tracks.reversed) {
      final _InternalTrackAddRemoveDescriptor(
        index: index,
        trackModel: track,
        isSendTrack: isSendTrack,
      ) = trackDescriptor;

      if (project.tracks[track.id] == null) {
        throw StateError(
          'Tried to remove a track that does not exist. This indicates bad usage '
          'of TrackAddRemoveCommand, or bad project state.',
        );
      }

      ServiceRegistry.forProject(
        project.id,
      ).arrangerViewModel.unregisterTrack(track.id);

      if (isSendTrack) {
        project.sendTrackOrder.remove(track.id);
      }
      else {
        project.trackOrder.remove(track.id);
      }

      project.tracks.remove(track.id);
    }

    final arrangerViewModel = ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel;

    arrangerViewModel.selectedTracks.removeAll(
      _tracks.map((t) => t.trackModel.id),
    );
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
