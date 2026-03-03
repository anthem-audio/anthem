/*
  Copyright (C) 2026 Joshua Wade

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
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';

/// Tracks notes that are sent to the engine during editing.
class PianoRollLiveNotes {
  final Map<int, ({double velocity, double pan})> _notes = {};
  final ProjectModel project;

  PianoRollLiveNotes(this.project);

  Id? _activeTrackId() {
    return project.sequence.activeTrackID;
  }

  bool hasNoteForKey(int key) {
    return _notes.containsKey(key);
  }

  void addNote({
    required int key,
    required double velocity,
    required double pan,
  }) {
    final activeTrackId = _activeTrackId();
    if (activeTrackId == null) {
      return;
    }

    final liveEventManager = ServiceRegistry.forProject(
      project.id,
    ).projectController.liveEventManager;

    if (_notes.containsKey(key)) {
      liveEventManager.noteOff(trackId: activeTrackId, pitch: key);
    }

    liveEventManager.noteOn(
      trackId: activeTrackId,
      pitch: key,
      velocity: velocity,
      pan: pan,
    );

    _notes[key] = (velocity: velocity, pan: pan);
  }

  void removeNote(int key) {
    final activeTrackId = _activeTrackId();
    if (activeTrackId == null) {
      return;
    }

    final liveEventManager = ServiceRegistry.forProject(
      project.id,
    ).projectController.liveEventManager;

    if (_notes.containsKey(key)) {
      liveEventManager.noteOff(trackId: activeTrackId, pitch: key);
      _notes.remove(key);
    }
  }

  void removeAll() {
    final activeTrackId = _activeTrackId();
    if (activeTrackId == null) {
      return;
    }

    final liveEventManager = ServiceRegistry.forProject(
      project.id,
    ).projectController.liveEventManager;

    for (final key in _notes.keys) {
      liveEventManager.noteOff(trackId: activeTrackId, pitch: key);
    }
    _notes.clear();
  }
}
