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

import 'package:anthem/commands/arrangement_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

abstract class ArrangementCommand extends Command {
  ID arrangementID;

  ArrangementCommand(ProjectModel project, this.arrangementID) : super(project);
}

/// Add a clip to an arrangement
class AddClipCommand extends ArrangementCommand {
  ID trackID;
  ID patternID;
  int offset;
  ID clipID = getID();
  TimeViewModel? timeView;

  AddClipCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.trackID,
    required this.patternID,
    required this.offset,
    this.timeView,
  }) : super(project, arrangementID);

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

    return [
      StateChange.arrangement(
        ArrangementStateChange.clipAdded(project.id, arrangementID),
      ),
    ];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements[arrangementID]!.clips.remove(clipID);

    return [
      StateChange.arrangement(
        ArrangementStateChange.clipDeleted(project.id, arrangementID),
      ),
    ];
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
      StateChange.arrangement(
        ArrangementStateChange.arrangementAdded(project.id, arrangementID),
      ),
    ];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements.remove(arrangementID);
    project.song.arrangementOrder.removeLast();

    return [
      StateChange.arrangement(
        ArrangementStateChange.arrangementDeleted(project.id, arrangementID),
      ),
    ];
  }
}

class SetArrangementNameCommand extends ArrangementCommand {
  late String oldName;
  String newName;

  SetArrangementNameCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.newName,
  }) : super(project, arrangementID) {
    oldName = project.song.arrangements[arrangementID]!.name;
  }

  @override
  List<StateChange> execute() {
    project.song.arrangements[arrangementID]!.name = newName;
    return [
      StateChange.arrangement(
        ArrangementStateChange.arrangementNameChanged(
            project.id, arrangementID),
      ),
    ];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements[arrangementID]!.name = oldName;
    return [
      StateChange.arrangement(
        ArrangementStateChange.arrangementNameChanged(
            project.id, arrangementID),
      ),
    ];
  }
}
