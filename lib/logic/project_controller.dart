/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'dart:async';
import 'dart:io';

import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/commands/pattern_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/live_event_manager.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef _ClipRemoveTarget = ({Id arrangementId, Id clipId});

class ProjectController {
  ProjectModel project;
  ProjectViewModel viewModel;
  late final LiveEventManager liveEventManager = LiveEventManager(project);

  ProjectController(this.project, this.viewModel);

  void undo() {
    project.undo();
  }

  void redo() {
    project.redo();
  }

  Id addPattern([String? name]) {
    if (name == null) {
      final patterns = project.sequence.patterns.nonObservableInner;
      var patternNumber = patterns.length;

      final existingNames = patterns.values.map((pattern) => pattern.name);

      do {
        patternNumber++;
        name = 'Pattern $patternNumber';
      } while (existingNames.contains(name));
    }

    final patternModel = PatternModel.create(name: name);

    project.execute(PatternAddRemoveCommand.add(pattern: patternModel));

    project.sequence.setActivePattern(patternModel.id);

    return patternModel.id;
  }

  void addArrangement([String? name]) {
    if (name == null) {
      final arrangements = project.sequence.arrangements.nonObservableInner;
      var arrangementNumber = arrangements.length;

      final existingNames = arrangements.values.map((pattern) => pattern.name);

      do {
        arrangementNumber++;
        name = 'Arrangement $arrangementNumber';
      } while (existingNames.contains(name));
    }

    final command = AddArrangementCommand(
      project: project,
      arrangementName: name,
    );

    project.execute(command);

    project.sequence.setActiveArrangement(command.arrangementID);
    project.sequence.activeTransportSequenceID = command.arrangementID;
  }

  void onShortcut(LogicalKeySet shortcut) {
    // Undo
    if (shortcut.matches(
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ),
    )) {
      undo();
    }
    // Redo
    else if (shortcut.matches(
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY),
        ) ||
        shortcut.matches(
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyZ,
          ),
        )) {
      redo();
    }
    // Play / stop
    else if (shortcut.matches(LogicalKeySet(LogicalKeyboardKey.space))) {
      togglePlayback();
    }
  }

  void togglePlayback() {
    if (project.engineState == EngineState.running) {
      project.sequence.isPlaying = !project.sequence.isPlaying;
    }
  }

  void setTrackInstrumentNode({required Id trackId, required NodeModel node}) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'ProjectController.setTrackInstrumentNode(): Track $trackId '
        'not found.',
      );
    }

    project.execute(
      SetTrackInstrumentNodeCommand(track: track, instrumentNode: node),
    );
  }

  void setTrackVst3InstrumentNode(Id trackId) async {
    final dialogController = ServiceRegistry.dialogController;
    String initialDirectory;

    if (Platform.isWindows) {
      initialDirectory = 'C:\\Program Files\\Common Files\\VST3';
    } else if (Platform.isMacOS) {
      initialDirectory = '/Library/Audio/Plug-Ins/VST3';
    } else if (Platform.isLinux) {
      initialDirectory = Platform.environment['HOME'] ?? '/';
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a plugin (VST3)',
      allowedExtensions: Platform.isMacOS ? null : ['vst3'],
      initialDirectory: initialDirectory,
      type: Platform.isMacOS ? FileType.custom : FileType.any,
    );

    final path = result?.files[0].path;

    if (path?.toLowerCase().endsWith('.vst3') != true) {
      dialogController.showTextDialog(
        title: 'Error',
        text:
            'The selected plugin could not be loaded. It may '
            'not be a valid VST3 plugin, or it may be incompatible.',
        buttons: [DialogButton.ok()],
      );
      return;
    }

    setTrackInstrumentNode(
      trackId: trackId,
      node: VST3ProcessorModel(vst3Path: path!).createNode(),
    );
  }

  void addTrack() {
    project.execute(
      TrackAddRemoveCommand.add(
        project: project,
        tracks: [.new(isSendTrack: false, trackType: .instrument)],
      ),
    );
  }

  void addSendTrack() {
    project.execute(
      TrackAddRemoveCommand.add(
        project: project,
        tracks: [.new(isSendTrack: true, trackType: .instrument)],
      ),
    );
  }

  void insertTrackAt(Id anchorTrackId) {
    final anchorTrack = project.tracks[anchorTrackId];

    if (anchorTrack == null) {
      throw StateError(
        'ProjectController.insertTrackAt(): Track $anchorTrackId not found.',
      );
    }

    final anchorIsSendTrack = isSendTrack(anchorTrackId);

    Id? parentTrackId;
    int? index;

    if (anchorTrack.type == TrackType.group) {
      parentTrackId = anchorTrack.id;
      index = anchorTrack.childTracks.length;
    } else if (anchorTrack.parentTrackId != null) {
      parentTrackId = anchorTrack.parentTrackId;
      final parentTrack = project.tracks[parentTrackId];

      if (parentTrack == null) {
        throw StateError(
          'ProjectController.insertTrackAt(): Parent track '
          '$parentTrackId not found for track $anchorTrackId.',
        );
      }

      final anchorIndex = parentTrack.childTracks.indexOf(anchorTrackId);
      if (anchorIndex == -1) {
        throw StateError(
          'ProjectController.insertTrackAt(): Track $anchorTrackId not found '
          'in child list of parent track $parentTrackId.',
        );
      }

      index = anchorIndex + 1;
    } else {
      final topLevelOrder = anchorIsSendTrack
          ? project.sendTrackOrder
          : project.trackOrder;
      final anchorIndex = topLevelOrder.indexOf(anchorTrackId);

      if (anchorIndex == -1) {
        throw StateError(
          'ProjectController.insertTrackAt(): Top-level track '
          '$anchorTrackId not found in ${anchorIsSendTrack ? 'sendTrackOrder' : 'trackOrder'}.',
        );
      }

      index = anchorIndex + 1;
    }

    project.execute(
      TrackAddRemoveCommand.add(
        project: project,
        tracks: [
          .new(
            index: index,
            isSendTrack: anchorIsSendTrack,
            trackType: .instrument,
            parentTrackId: parentTrackId,
          ),
        ],
      ),
    );
  }

  void removeTrack(Id trackId) {
    removeTracks([trackId]);
  }

  /// Removes tracks and any sequencer content that points to them.
  ///
  /// Clips are conceptually owned by tracks, but all clips are truly owned by a
  /// single map in the model. If we removed tracks without removing the clips
  /// associated with those tracks, we would leak clips in the project file,
  /// with no way for them to be cleaned up. So we first remove clips on the
  /// removed track set (including descendants), then remove any patterns that
  /// become orphaned, and finally remove the tracks.
  void removeTracks(Iterable<Id> trackIds) {
    final trackIdsToRemove = trackIds.toList(growable: false);
    final trackRemoveCommand = TrackAddRemoveCommand.remove(
      project: project,
      ids: trackIdsToRemove,
    );

    final clipDeleteTargets = _collectClipDeleteTargetsForTracks(
      trackIdsToRemove,
    );
    final clipAndPatternDeletionPlan = _buildClipAndPatternDeletionPlan(
      clipDeleteTargets,
    );

    project.startUndoGroup();

    _executeClipAndPatternDeletionPlan(clipAndPatternDeletionPlan);

    project.execute(trackRemoveCommand);

    project.commitUndoGroup();
  }

  ({Set<Id> deletedClipIds, Set<Id> deletedPatternIds}) deleteClips({
    required Id arrangementId,
    required Iterable<Id> clipIds,
  }) {
    final clipDeleteTargets = clipIds.map(
      (clipId) => (arrangementId: arrangementId, clipId: clipId),
    );

    final clipAndPatternDeletionPlan = _buildClipAndPatternDeletionPlan(
      clipDeleteTargets,
    );

    if (clipAndPatternDeletionPlan.clipsToDelete.isEmpty) {
      return (deletedClipIds: {}, deletedPatternIds: {});
    }

    project.startUndoGroup();
    _executeClipAndPatternDeletionPlan(clipAndPatternDeletionPlan);
    project.commitUndoGroup();

    return (
      deletedClipIds: clipAndPatternDeletionPlan.clipsToDelete
          .map((clip) => clip.clipId)
          .toSet(),
      deletedPatternIds: clipAndPatternDeletionPlan.patternIdsToDelete.toSet(),
    );
  }

  /// Checks if a given track is a send track, or a child of a grouped send
  /// track.
  bool isSendTrack(Id trackId, [bool observable = true]) {
    final projectTracks = observable
        ? project.tracks
        : project.tracks.nonObservableInner;

    final sendTrackOrder = observable
        ? project.sendTrackOrder
        : project.sendTrackOrder.nonObservableInner;

    int safetyCounter = 0;
    Id? currentTrackId = trackId;

    while (currentTrackId != null && safetyCounter < 100_000) {
      safetyCounter++;

      final currentTrack = projectTracks[currentTrackId]!;
      if (currentTrack.parentTrackId == null &&
          sendTrackOrder.contains(currentTrackId)) {
        return true;
      }

      currentTrackId = currentTrack.parentTrackId;
    }

    return false;
  }

  Iterable<_ClipRemoveTarget> _collectClipDeleteTargetsForTracks(
    Iterable<Id> trackIds,
  ) sync* {
    final tracksToDelete = _collectTrackIdsIncludingDescendants(trackIds);

    for (final arrangementEntry in project.sequence.arrangements.entries) {
      for (final clipEntry in arrangementEntry.value.clips.entries) {
        if (tracksToDelete.contains(clipEntry.value.trackId)) {
          yield (arrangementId: arrangementEntry.key, clipId: clipEntry.key);
        }
      }
    }
  }

  List<Id> _collectTrackIdsIncludingDescendants(Iterable<Id> trackIds) {
    final tracksToDelete = <Id>[];

    void collect(Id trackId) {
      if (tracksToDelete.contains(trackId)) {
        return;
      }
      tracksToDelete.add(trackId);

      final track = project.tracks[trackId];
      if (track == null) {
        return;
      }

      for (final childTrackId in track.childTracks) {
        collect(childTrackId);
      }
    }

    for (final trackId in trackIds) {
      collect(trackId);
    }

    return tracksToDelete;
  }

  /// Builds a normalized delete plan for clips and patterns.
  ///
  /// Normalization means:
  /// - clip targets are deduplicated so each clip is removed once
  /// - pattern IDs are deduplicated so shared patterns are evaluated once
  ///   against global remaining clip references before deciding deletion
  ({List<_ClipRemoveTarget> clipsToDelete, List<Id> patternIdsToDelete})
  _buildClipAndPatternDeletionPlan(Iterable<_ClipRemoveTarget> clipTargets) {
    final clipsToDelete = <({Id arrangementId, Id clipId, Id patternId})>[];

    // We deduplicate clip targets so repeated clip IDs (or overlapping callers)
    // do not enqueue duplicate remove commands for the same clip.
    final seenTargets = <_ClipRemoveTarget>{};

    for (final target in clipTargets) {
      if (!seenTargets.add(target)) {
        continue;
      }

      final arrangement = project.sequence.arrangements[target.arrangementId];
      final clip = arrangement?.clips[target.clipId];
      if (clip == null) {
        continue;
      }

      clipsToDelete.add((
        arrangementId: target.arrangementId,
        clipId: target.clipId,
        patternId: clip.patternId,
      ));
    }

    if (clipsToDelete.isEmpty) {
      return (clipsToDelete: [], patternIdsToDelete: []);
    }

    // We deduplicate pattern IDs because many clips can point to the same
    // pattern, and we only want to evaluate/delete each pattern once.
    final candidatePatternIds = clipsToDelete
        .map((clip) => clip.patternId)
        .toSet();
    final remainingPatternRefCounts = <Id, int>{
      for (final patternId in candidatePatternIds) patternId: 0,
    };

    for (final arrangement in project.sequence.arrangements.values) {
      for (final clip in arrangement.clips.values) {
        if (!candidatePatternIds.contains(clip.patternId)) {
          continue;
        }

        remainingPatternRefCounts[clip.patternId] =
            remainingPatternRefCounts[clip.patternId]! + 1;
      }
    }

    for (final clip in clipsToDelete) {
      remainingPatternRefCounts[clip.patternId] =
          (remainingPatternRefCounts[clip.patternId] ?? 0) - 1;
    }

    final patternIdsToDelete = remainingPatternRefCounts.entries
        .where(
          (entry) =>
              entry.value <= 0 && project.sequence.patterns[entry.key] != null,
        )
        .map((entry) => entry.key)
        .toList(growable: false);

    return (
      clipsToDelete: clipsToDelete
          .map(
            (clip) => (arrangementId: clip.arrangementId, clipId: clip.clipId),
          )
          .toList(growable: false),
      patternIdsToDelete: patternIdsToDelete,
    );
  }

  void _executeClipAndPatternDeletionPlan(
    ({List<_ClipRemoveTarget> clipsToDelete, List<Id> patternIdsToDelete}) plan,
  ) {
    for (final clip in plan.clipsToDelete) {
      project.execute(
        ClipAddRemoveCommand.remove(
          arrangementID: clip.arrangementId,
          clipId: clip.clipId,
          project: project,
        ),
      );
    }

    for (final patternId in plan.patternIdsToDelete) {
      if (!project.sequence.patterns.containsKey(patternId)) {
        continue;
      }

      project.execute(
        PatternAddRemoveCommand.remove(project: project, patternId: patternId),
      );
    }
  }

  /// Note that this DOES NOT WORK with MobX observers. We assume that we will
  /// not need to ask this question when rendering a view, and the iterating
  /// here can get quite expensive.
  bool canGroupTracks(Iterable<Id> trackIds) {
    if (trackIds.isEmpty) return false;

    bool hasSendTracks = false;
    bool hasRegularTracks = false;

    for (final id in trackIds) {
      final track = project.tracks[id];
      if (track == null) {
        continue;
      }

      if (track.isMasterTrack) {
        return false;
      }

      final isSendTrack = this.isSendTrack(id, false);

      hasSendTracks = hasSendTracks || isSendTrack;
      hasRegularTracks = hasRegularTracks || !isSendTrack;

      if (hasSendTracks && hasRegularTracks) {
        return false;
      }
    }

    return true;
  }

  void groupTracks(Iterable<Id> trackIds) {
    project.execute(
      TrackGroupUngroupCommand.group(project: project, trackIds: trackIds),
    );
  }

  void setTrackName(Id trackId, String newName) {
    project.execute(
      SetTrackNameCommand(track: project.tracks[trackId]!, newName: newName),
    );
  }

  void setTrackColor(Id trackId, double hue, AnthemColorPaletteKind palette) {
    project.execute(
      SetTrackColorCommand(
        track: project.tracks[trackId]!,
        newHue: hue,
        newPalette: palette,
      ),
    );
  }

  void setActiveArrangement(Id? id) {
    project.sequence.setActiveArrangement(id);
    _updateTransportSequenceID(id);
  }

  void setActiveEditor({required EditorKind editor}) {
    viewModel.selectedEditor = editor;

    viewModel.activePanel = switch (editor) {
      .detail => .pianoRoll,
      .automation => .automationEditor,
      .channelRack => .channelRack,
      .mixer => .mixer,
    };
  }

  void setActivePattern(Id? id) {
    project.sequence.setActivePattern(id);
    _updateTransportSequenceID(id);
  }

  void setActiveTrack(Id? id) {
    project.sequence.setActiveTrack(id);
  }

  void openPatternInPianoRoll(Id patternID) {
    if (!project.sequence.patterns.containsKey(patternID)) {
      return;
    }

    setActiveEditor(editor: EditorKind.detail);
    project.sequence.setActivePattern(patternID);
  }

  void _updateTransportSequenceID(Id? id) {
    project.sequence.activeTransportSequenceID = id;
    if (id != null) {
      project.visualizationProvider.overrideValue(
        id: 'playhead_sequence_id',
        stringValue: id,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  /// Closes the project.
  ///
  /// Returns true if the project was closed, false if the close was cancelled.
  Future<bool> close() {
    final dialogController = ServiceRegistry.dialogController;
    final mainWindowController = ServiceRegistry.mainWindowController;

    final completer = Completer<bool>();

    if (project.isDirty) {
      dialogController.showTextDialog(
        title: 'Unsaved Changes',
        text:
            'The project "${project.name}" has unsaved changes.\n\n'
            'Do you want to save before closing?',
        onDismiss: () {
          completer.complete(false);
        },
        buttons: [
          DialogButton(text: 'Cancel', isDismissive: true),
          DialogButton(
            text: "Don't Save",
            onPress: () {
              mainWindowController.closeProjectWithoutSaving(project.id);
              completer.complete(true);
            },
          ),
          DialogButton(
            text: 'Save',
            onPress: () async {
              final result = await mainWindowController.saveProject(
                project.id,
                false,
                dialogController: dialogController,
              );
              if (result) {
                mainWindowController.closeProjectWithoutSaving(project.id);
              }
              completer.complete(result);
            },
          ),
        ],
      );
    } else {
      mainWindowController.closeProjectWithoutSaving(project.id);
      completer.complete(true);
    }

    completer.future.then((_) {
      ServiceRegistry.removeProject(project.id);
    });

    return completer.future;
  }
}
