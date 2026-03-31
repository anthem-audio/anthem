/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';

/// Manages live note events for tracks.
///
/// Each live note request gets a stable source note ID so the engine can
/// translate it into a runtime-emitted note ID without relying on pitch-only
/// matching.
class LiveEventManager {
  final ProjectModel project;
  final Map<Id, Map<int, List<int>>> _activeNoteIdsByTrackAndPitch = {};
  int _nextSourceNoteId = 0;

  LiveEventManager(this.project);

  Id? _getLiveEventProviderNodeId(Id trackId) {
    final track = project.tracks[trackId];
    return track?.liveEventProviderNodeId;
  }

  int _allocateSourceNoteId() {
    final noteId = _nextSourceNoteId;
    _nextSourceNoteId++;
    return noteId;
  }

  void _rememberActiveNote({
    required Id trackId,
    required int pitch,
    required int noteId,
  }) {
    final notesByPitch = _activeNoteIdsByTrackAndPitch.putIfAbsent(
      trackId,
      () => {},
    );
    final activeNoteIds = notesByPitch.putIfAbsent(pitch, () => []);
    activeNoteIds.add(noteId);
  }

  void _forgetActiveNote({
    required Id trackId,
    required int pitch,
    required int noteId,
  }) {
    final notesByPitch = _activeNoteIdsByTrackAndPitch[trackId];
    final activeNoteIds = notesByPitch?[pitch];
    if (activeNoteIds == null) {
      return;
    }

    activeNoteIds.remove(noteId);
    if (activeNoteIds.isEmpty) {
      notesByPitch?.remove(pitch);
    }
    if (notesByPitch != null && notesByPitch.isEmpty) {
      _activeNoteIdsByTrackAndPitch.remove(trackId);
    }
  }

  int? _takeMostRecentActiveNoteId({required Id trackId, required int pitch}) {
    final notesByPitch = _activeNoteIdsByTrackAndPitch[trackId];
    final activeNoteIds = notesByPitch?[pitch];
    if (activeNoteIds == null || activeNoteIds.isEmpty) {
      return null;
    }

    final noteId = activeNoteIds.removeLast();
    if (activeNoteIds.isEmpty) {
      notesByPitch?.remove(pitch);
    }
    if (notesByPitch != null && notesByPitch.isEmpty) {
      _activeNoteIdsByTrackAndPitch.remove(trackId);
    }

    return noteId;
  }

  int noteOn({
    required Id trackId,
    required int pitch,
    required double velocity,
    required double pan,
    int channel = 0,
  }) {
    final noteId = _allocateSourceNoteId();

    if (!project.engine.isRunning) {
      return noteId;
    }

    final liveEventProviderNodeId = _getLiveEventProviderNodeId(trackId);
    if (liveEventProviderNodeId == null) {
      return noteId;
    }

    project.engine.processingGraphApi.sendLiveEvent(
      liveEventProviderNodeId,
      LiveEventRequestNoteOnEvent(
        noteId: noteId,
        pitch: pitch,
        channel: channel,
        velocity: velocity,
        pan: pan,
      ),
    );

    _rememberActiveNote(trackId: trackId, pitch: pitch, noteId: noteId);
    return noteId;
  }

  void noteOff({required Id trackId, required int pitch, int channel = 0}) {
    final noteId = _takeMostRecentActiveNoteId(trackId: trackId, pitch: pitch);
    if (noteId == null) {
      return;
    }

    noteOffById(
      trackId: trackId,
      noteId: noteId,
      pitch: pitch,
      channel: channel,
    );
  }

  void noteOffById({
    required Id trackId,
    required int noteId,
    required int pitch,
    int channel = 0,
  }) {
    if (!project.engine.isRunning) {
      _forgetActiveNote(trackId: trackId, pitch: pitch, noteId: noteId);
      return;
    }

    final liveEventProviderNodeId = _getLiveEventProviderNodeId(trackId);
    if (liveEventProviderNodeId == null) {
      _forgetActiveNote(trackId: trackId, pitch: pitch, noteId: noteId);
      return;
    }

    project.engine.processingGraphApi.sendLiveEvent(
      liveEventProviderNodeId,
      LiveEventRequestNoteOffEvent(
        noteId: noteId,
        pitch: pitch,
        channel: channel,
      ),
    );

    _forgetActiveNote(trackId: trackId, pitch: pitch, noteId: noteId);
  }
}
