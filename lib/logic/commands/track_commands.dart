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

class TrackAddRemoveCommand extends Command {
  final bool isAdd;
  bool get isRemove => !isAdd;

  late final TrackModel track;
  int? index;
  late final bool isSendTrack;

  TrackAddRemoveCommand.add({
    required ProjectModel project,
    this.index,
    required this.isSendTrack,
  }) : isAdd = true {
    track = TrackModel(
      name: isSendTrack
          ? 'Send Track ${project.sendTrackOrder.length}'
          : 'Track ${project.trackOrder.length + 1}',
      color: AnthemColor.randomHue(),
    );
  }

  TrackAddRemoveCommand.remove({required ProjectModel project, required Id id})
    : isAdd = false {
    track = project.tracks[id]!;
    index = project.trackOrder.indexOf(id);

    if (index == -1) {
      index = project.sendTrackOrder.indexOf(id);
      isSendTrack = true;
    } else {
      isSendTrack = false;
    }
  }

  @override
  void execute(ProjectModel project) {
    if (isAdd) {
      _add(project);
    } else {
      _remove(project);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (isAdd) {
      _remove(project);
    } else {
      _add(project);
    }
  }

  void _add(ProjectModel project) {
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
      orderListToModify.insert(index!, track.id);
    }

    project.tracks[track.id] = track;

    ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel.registerTrack(track.id);
  }

  void _remove(ProjectModel project) {
    if (project.tracks[track.id] == null) {
      throw StateError(
        'Tried to remove a track that does not exist. This indicates bad usage '
        'of TrackAddRemoveCommand, or bad project state.',
      );
    }

    ServiceRegistry.forProject(
      project.id,
    ).arrangerViewModel.unregisterTrack(track.id);

    project.trackOrder.remove(track.id);
    project.tracks.remove(track.id);
  }
}
