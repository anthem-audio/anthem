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

class MoveClipsCommand extends ArrangementCommand {
  final List<({Id clipID, int oldOffset, int newOffset})> clipMoves;

  MoveClipsCommand({
    required Id arrangementID,
    required List<({Id clipID, int oldOffset, int newOffset})> clipMoves,
  }) : clipMoves = List.unmodifiable(clipMoves),
       super(arrangementID);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;

    for (final clipMove in clipMoves) {
      final clip = arrangement.clips[clipMove.clipID]!;
      clip.offset = clipMove.newOffset;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;

    for (final clipMove in clipMoves.reversed) {
      final clip = arrangement.clips[clipMove.clipID]!;
      clip.offset = clipMove.oldOffset;
    }
  }
}

class ResizeClipsCommand extends ArrangementCommand {
  final List<
    ({
      Id clipID,
      int oldOffset,
      TimeViewModel? oldTimeView,
      int newOffset,
      TimeViewModel newTimeView,
    })
  >
  clipResizes;

  ResizeClipsCommand({
    required Id arrangementID,
    required List<
      ({
        Id clipID,
        int oldOffset,
        TimeViewModel? oldTimeView,
        int newOffset,
        TimeViewModel newTimeView,
      })
    >
    clipResizes,
  }) : clipResizes = List.unmodifiable(
         clipResizes.map(
           (clipResize) => (
             clipID: clipResize.clipID,
             oldOffset: clipResize.oldOffset,
             oldTimeView: clipResize.oldTimeView?.clone(),
             newOffset: clipResize.newOffset,
             newTimeView: clipResize.newTimeView.clone(),
           ),
         ),
       ),
       super(arrangementID);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;

    for (final clipResize in clipResizes) {
      final clip = arrangement.clips[clipResize.clipID]!;
      clip.offset = clipResize.newOffset;
      clip.timeView = clipResize.newTimeView.clone();
    }
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangements[arrangementID]!;

    for (final clipResize in clipResizes.reversed) {
      final clip = arrangement.clips[clipResize.clipID]!;
      clip.offset = clipResize.oldOffset;
      clip.timeView = clipResize.oldTimeView?.clone();
    }
  }
}
