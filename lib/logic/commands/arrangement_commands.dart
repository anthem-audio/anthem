/*
  Copyright (C) 2022 - 2026 Joshua Wade

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
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

void _addClipToArrangement({
  required ProjectModel project,
  required ClipModel clip,
}) {
  project.sequence.arrangement.clips[clip.id] = clip;
}

void _removeClipFromArrangement({
  required ProjectModel project,
  required Id clipId,
}) {
  project.sequence.arrangement.clips.remove(clipId);
}

class ClipAddRemoveCommand extends Command {
  final bool _isAdd;

  late final ClipModel clip;

  ClipAddRemoveCommand.add({required this.clip}) : _isAdd = true;

  ClipAddRemoveCommand.remove({
    required ProjectModel project,
    required Id clipId,
  }) : _isAdd = false {
    final arrangement = project.sequence.arrangement;

    final foundClip = arrangement.clips[clipId];
    if (foundClip == null) {
      throw StateError(
        'ClipAddRemoveCommand.remove(): Clip $clipId not found in the '
        'arrangement.',
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
    final arrangement = project.sequence.arrangement;

    if (arrangement.clips[clip.id] != null) {
      throw StateError(
        'Tried to add a clip that already exists. This indicates bad usage of '
        'ClipAddRemoveCommand, or bad project state.',
      );
    }

    _addClipToArrangement(project: project, clip: clip);
  }

  void _remove(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    if (arrangement.clips[clip.id] == null) {
      throw StateError(
        'Tried to remove a clip that does not exist. This indicates bad usage '
        'of ClipAddRemoveCommand, or bad project state.',
      );
    }

    _removeClipFromArrangement(project: project, clipId: clip.id);
  }
}

class SetArrangementNameCommand extends Command {
  late final String oldName;
  final String newName;

  SetArrangementNameCommand({
    required ProjectModel project,
    required this.newName,
  }) {
    oldName = project.sequence.arrangement.name;
  }

  @override
  void execute(ProjectModel project) {
    project.sequence.arrangement.name = newName;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.arrangement.name = oldName;
  }
}

class MoveClipsCommand extends Command {
  final List<({Id clipID, int oldOffset, int newOffset})> clipMoves;

  MoveClipsCommand({
    required List<({Id clipID, int oldOffset, int newOffset})> clipMoves,
  }) : clipMoves = List.unmodifiable(clipMoves);

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    for (final clipMove in clipMoves) {
      final clip = arrangement.clips[clipMove.clipID]!;
      clip.offset = clipMove.newOffset;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    for (final clipMove in clipMoves.reversed) {
      final clip = arrangement.clips[clipMove.clipID]!;
      clip.offset = clipMove.oldOffset;
    }
  }
}

class ResizeClipsCommand extends Command {
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
       );

  @override
  void execute(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    for (final clipResize in clipResizes) {
      final clip = arrangement.clips[clipResize.clipID]!;
      clip.offset = clipResize.newOffset;
      clip.timeView = clipResize.newTimeView.clone();
    }
  }

  @override
  void rollback(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    for (final clipResize in clipResizes.reversed) {
      final clip = arrangement.clips[clipResize.clipID]!;
      clip.offset = clipResize.oldOffset;
      clip.timeView = clipResize.oldTimeView?.clone();
    }
  }
}
