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
import 'package:anthem/logic/commands/project_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ProjectController {
  ProjectModel project;
  ProjectViewModel viewModel;

  ProjectController(this.project, this.viewModel);

  void undo() {
    project.undo();
  }

  void redo() {
    project.redo();
  }

  void setActiveGeneratorID(Id id) {
    project.activeInstrumentID = id;
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

  void addGenerator({
    required NodeModel node,
    required String name,
    required GeneratorType generatorType,
    required Color color,
  }) {
    final id = getId();

    project.execute(
      AddGeneratorCommand(
        generatorId: id,
        node: node,
        name: name,
        generatorType: generatorType,
        color: color,
      ),
    );

    if (generatorType == GeneratorType.instrument) {
      project.activeInstrumentID = id;
    } else if (generatorType == GeneratorType.automation) {
      project.activeAutomationGeneratorID = id;
    }
  }

  void tempDevAddGeneratorNodeToTrack({
    required Id trackId,
    required NodeModel node,
  }) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'ProjectController.tempDevAddGeneratorNodeToTrack(): Track $trackId '
        'not found.',
      );
    }

    project.execute(
      TempDevAddGeneratorToTrackCommand(track: track, generatorNode: node),
    );
  }

  void tempDevAddVst3GeneratorNodeToTrack(Id trackId) async {
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

    tempDevAddGeneratorNodeToTrack(
      trackId: trackId,
      node: VST3ProcessorModel(vst3Path: path!).createNode(),
    );
  }

  void addVst3Generator() async {
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

    addGenerator(
      name: 'VST Plugin',
      generatorType: GeneratorType.instrument,
      color: generateColor(),
      node: VST3ProcessorModel(vst3Path: path!).createNode(),
    );
  }

  void removeGenerator(Id generatorID) {
    project.execute(
      RemoveGeneratorCommand(
        project: project,
        generator: project.generators[generatorID]!,
      ),
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
    project.execute(
      TrackAddRemoveCommand.remove(project: project, ids: [trackId]),
    );
  }

  void removeTracks(Iterable<Id> trackIds) {
    project.execute(
      TrackAddRemoveCommand.remove(project: project, ids: trackIds),
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

var nextHue = 0.0;

Color generateColor() {
  final color = HSLColor.fromAHSL(1, nextHue, 0.33, 0.5).toColor();
  nextHue = (nextHue + 330) % 360;
  return color;
}
