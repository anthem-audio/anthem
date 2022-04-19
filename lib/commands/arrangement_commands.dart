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
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

/// Add a clip to an arrangement
class AddClipCommand extends Command {
  int arrangementID;
  int trackID;
  int patternID;
  int offset;
  int clipID = getID();
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
    project.song.arrangements[arrangementID]!.clips[clipID] = ClipModel(
      offset: offset,
      patternID: patternID,
      trackID: trackID,
      timeView: timeView,
    );

    return [ClipAdded(projectID: project.id, arrangementID: arrangementID)];
  }

  @override
  List<StateChange> rollback() {
    project.song.arrangements[arrangementID]!.clips.remove(clipID);

    return [ClipDeleted(projectID: project.id, arrangementID: arrangementID)];
  }
}
