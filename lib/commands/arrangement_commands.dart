/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

/// Add a clip to an arrangement
class AddClipCommand extends Command {
  ID arrangementID;
  ID trackID;
  ID patternID;
  int offset;
  ID clipID = getID();
  TimeViewModel? timeView;

  AddClipCommand({
    required ProjectModel project,
    required this.arrangementID,
    required this.trackID,
    required this.patternID,
    required this.offset,
    this.timeView,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final clipModel = ClipModel.create(
      offset: offset,
      patternID: patternID,
      trackID: trackID,
      timeView: timeView,
      project: project,
    );

    project.song.arrangements[arrangementID]!.clips[clipID] = clipModel;

    return [ClipAdded(projectID: project.id, arrangementID: arrangementID)];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements[arrangementID]!.clips.remove(clipID);

    return [ClipDeleted(projectID: project.id, arrangementID: arrangementID)];
  }
}

class AddArrangementCommand extends Command {
  ID arrangementID = getID();
  String arrangementName;

  AddArrangementCommand({
    required ProjectModel project,
    required this.arrangementName,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final arrangement = ArrangementModel.create(
      name: arrangementName,
      id: arrangementID,
      project: project,
    );
    project.song.arrangements[arrangementID] = arrangement;
    project.song.arrangementOrder.add(arrangementID);

    return [
      ArrangementAdded(projectID: project.id, arrangementID: arrangementID),
    ];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements.remove(arrangementID);
    project.song.arrangementOrder.removeLast();

    return [
      ArrangementDeleted(projectID: project.id, arrangementID: arrangementID),
    ];
  }
}
