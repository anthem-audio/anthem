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
  final Id arrangementID;

  ArrangementCommand(this.arrangementID);
}

/// Add a clip to an arrangement
class AddClipCommand extends ArrangementCommand {
  final ClipModel clip;

  AddClipCommand({required Id arrangementID, required this.clip})
    : super(arrangementID);

  @override
  void execute(ProjectModel project) {
    project.sequence.arrangements[arrangementID]!.clips[clip.id] = clip;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.arrangements[arrangementID]!.clips.remove(clip.id);
  }
}

class AddArrangementCommand extends Command {
  final Id arrangementID = getId();
  final String arrangementName;

  AddArrangementCommand({
    required ProjectModel project,
    required this.arrangementName,
  });

  @override
  void execute(ProjectModel project) {
    final arrangement = ArrangementModel.create(
      name: arrangementName,
      id: arrangementID,
    );

    project.sequence.arrangements[arrangementID] = arrangement;
    project.sequence.arrangementOrder.add(arrangementID);
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.arrangementOrder.removeLast();
  }
}

class DeleteArrangementCommand extends Command {
  final ArrangementModel arrangement;
  late final int index;

  DeleteArrangementCommand({
    required ProjectModel project,
    required this.arrangement,
  });

  @override
  void execute(ProjectModel project) {
    project.sequence.arrangements.remove(arrangement.id);
    index = project.sequence.arrangementOrder.indexOf(arrangement.id);
    project.sequence.arrangementOrder.removeAt(index);
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.arrangements[arrangement.id] = arrangement;
    project.sequence.arrangementOrder.insert(index, arrangement.id);
  }
}

class SetArrangementNameCommand extends ArrangementCommand {
  late final String oldName;
  final String newName;

  SetArrangementNameCommand({
    required ProjectModel project,
    required Id arrangementID,
    required this.newName,
  }) : super(arrangementID) {
    oldName = project.sequence.arrangements[arrangementID]!.name;
  }

  @override
  void execute(ProjectModel project) {
    project.sequence.arrangements[arrangementID]!.name = newName;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.arrangements[arrangementID]!.name = oldName;
  }
}

class MoveClipCommand extends ArrangementCommand {
  final Id clipID;
  final int oldOffset;
  final int newOffset;
  final Id oldTrack;
  final Id newTrack;

  MoveClipCommand({
    required Id arrangementID,
    required this.clipID,
    required this.oldOffset,
    required this.newOffset,
    required this.oldTrack,
    required this.newTrack,
  }) : super(arrangementID);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = newOffset;
    clip.trackId = newTrack;
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = oldOffset;
    clip.trackId = oldTrack;
  }
}

class DeleteClipCommand extends ArrangementCommand {
  final ClipModel clip;

  DeleteClipCommand({required Id arrangementID, required this.clip})
    : super(arrangementID);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    arrangement.clips.remove(clip.id);
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    arrangement.clips[clip.id] = clip;
  }
}

class ResizeClipCommand extends ArrangementCommand {
  final Id clipID;
  final int oldOffset;
  final TimeViewModel? oldTimeView;
  final int newOffset;
  final TimeViewModel? newTimeView;

  ResizeClipCommand({
    required Id arrangementID,
    required this.clipID,
    required this.oldOffset,
    required this.oldTimeView,
    required this.newOffset,
    required this.newTimeView,
  }) : super(arrangementID);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = newOffset;
    clip.timeView = newTimeView;
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;
    final clip = arrangement.clips[clipID]!;

    clip.offset = oldOffset;
    clip.timeView = oldTimeView;
  }
}
