/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

abstract class ArrangementCommand extends Command {
  final ID arrangementID;

  ArrangementCommand(ProjectModel project, this.arrangementID) : super(project);
}

/// Add a clip to an arrangement
class AddClipCommand extends ArrangementCommand {
  final ClipModel clip;

  AddClipCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.clip,
  }) : super(project, arrangementID);

  @override
  void execute() {
    project.song.arrangements[arrangementID]!.clips[clip.id] = clip;
  }

  @override
  void rollback() {
    project.song.arrangements[arrangementID]!.clips.remove(clip.id);
  }
}

class AddArrangementCommand extends Command {
  final ID arrangementID = getID();
  final String arrangementName;

  AddArrangementCommand({
    required ProjectModel project,
    required this.arrangementName,
  }) : super(project);

  @override
  void execute() {
    final arrangement = ArrangementModel.create(
      name: arrangementName,
      id: arrangementID,
      project: project,
    );
    arrangement.createInEngine(project.engine);

    project.song.arrangements[arrangementID] = arrangement;
    project.song.arrangementOrder.add(arrangementID);
  }

  @override
  void rollback() {
    final arrangement = project.song.arrangements.remove(arrangementID)!;
    project.song.arrangementOrder.removeLast();

    // Remove from engine
    final editPointer = arrangement.editPointer;
    project.engine.projectApi.deleteArrangement(editPointer);
  }
}

class DeleteArrangementCommand extends Command {
  final ArrangementModel arrangement;

  DeleteArrangementCommand({
    required ProjectModel project,
    required this.arrangement,
  }) : super(project);

  @override
  void execute() {
    arrangement.deleteInEngine(project.engine);
    project.song.arrangements.remove(arrangement.id);
    project.song.arrangementOrder.remove(arrangement.id);
  }

  @override
  void rollback() {
    arrangement.createInEngine(project.engine);
    project.song.arrangements[arrangement.id] = arrangement;
    // project.song.arrangementOrder
    // TODO: Correct ordering and put it back in the arrangement!
  }
}

class SetArrangementNameCommand extends ArrangementCommand {
  late final String oldName;
  final String newName;

  SetArrangementNameCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.newName,
  }) : super(project, arrangementID) {
    oldName = project.song.arrangements[arrangementID]!.name;
  }

  @override
  void execute() {
    project.song.arrangements[arrangementID]!.name = newName;
  }

  @override
  void rollback() {
    project.song.arrangements[arrangementID]!.name = oldName;
  }
}

class MoveClipCommand extends ArrangementCommand {
  final ID clipID;
  final int oldOffset;
  final int newOffset;
  final ID oldTrack;
  final ID newTrack;

  MoveClipCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.clipID,
    required this.oldOffset,
    required this.newOffset,
    required this.oldTrack,
    required this.newTrack,
  }) : super(project, arrangementID);

  @override
  void execute() {
    final arrangement = project.song.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = newOffset;
    clip.trackID = newTrack;
  }

  @override
  void rollback() {
    final arrangement = project.song.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = oldOffset;
    clip.trackID = oldTrack;
  }
}

class DeleteClipCommand extends ArrangementCommand {
  final ClipModel clip;

  DeleteClipCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.clip,
  }) : super(project, arrangementID);

  @override
  void execute() {
    final arrangement = project.song.arrangements[arrangementID]!;
    arrangement.clips.remove(clip.id);
  }

  @override
  void rollback() {
    final arrangement = project.song.arrangements[arrangementID]!;
    arrangement.clips[clip.id] = clip;
  }
}

class ResizeClipCommand extends ArrangementCommand {
  final ID clipID;
  final int oldOffset;
  final TimeViewModel? oldTimeView;
  final int newOffset;
  final TimeViewModel? newTimeView;

  ResizeClipCommand({
    required ProjectModel project,
    required ID arrangementID,
    required this.clipID,
    required this.oldOffset,
    required this.oldTimeView,
    required this.newOffset,
    required this.newTimeView,
  }) : super(project, arrangementID);

  @override
  void execute() {
    final arrangement = project.song.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = newOffset;
    clip.timeView = newTimeView;
  }

  @override
  void rollback() {
    final arrangement = project.song.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = oldOffset;
    clip.timeView = oldTimeView;
  }
}
