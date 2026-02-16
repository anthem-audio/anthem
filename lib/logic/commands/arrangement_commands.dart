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

void _addClipToArrangement({
  required ProjectModel project,
  required Id arrangementId,
  required ClipModel clip,
}) {
  project.sequence.arrangements[arrangementId]!.clips[clip.id] = clip;
}

void _removeClipFromArrangement({
  required ProjectModel project,
  required Id arrangementId,
  required Id clipId,
}) {
  project.sequence.arrangements[arrangementId]!.clips.remove(clipId);
}

class ClipAddRemoveCommand extends ArrangementCommand {
  final bool _isAdd;

  late final ClipModel clip;

  ClipAddRemoveCommand.add({required Id arrangementID, required this.clip})
    : _isAdd = true,
      super(arrangementID);

  ClipAddRemoveCommand.remove({
    required ProjectModel project,
    required Id arrangementID,
    required Id clipId,
  }) : _isAdd = false,
       super(arrangementID) {
    final arrangement = project.sequence.arrangements[arrangementID];
    if (arrangement == null) {
      throw StateError(
        'ClipAddRemoveCommand.remove(): Arrangement $arrangementID not found.',
      );
    }

    final foundClip = arrangement.clips[clipId];
    if (foundClip == null) {
      throw StateError(
        'ClipAddRemoveCommand.remove(): Clip $clipId not found in arrangement '
        '$arrangementID.',
      );
    }

    clip = foundClip;
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
    final arrangement = project.sequence.arrangements[arrangementID];
    if (arrangement == null) {
      throw StateError(
        'ClipAddRemoveCommand.add(): Arrangement $arrangementID not found.',
      );
    }

    if (arrangement.clips[clip.id] != null) {
      throw StateError(
        'Tried to add a clip that already exists. This indicates bad usage of '
        'ClipAddRemoveCommand, or bad project state.',
      );
    }

    _addClipToArrangement(
      project: project,
      arrangementId: arrangementID,
      clip: clip,
    );
  }

  void _remove(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID];
    if (arrangement == null) {
      throw StateError(
        'ClipAddRemoveCommand.remove(): Arrangement $arrangementID not found.',
      );
    }

    if (arrangement.clips[clip.id] == null) {
      throw StateError(
        'Tried to remove a clip that does not exist. This indicates bad usage '
        'of ClipAddRemoveCommand, or bad project state.',
      );
    }

    _removeClipFromArrangement(
      project: project,
      arrangementId: arrangementID,
      clipId: clip.id,
    );
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
    project.sequence.arrangements.remove(arrangementID);
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
