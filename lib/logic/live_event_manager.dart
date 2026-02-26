/*
  Copyright (C) 2025 Joshua Wade

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
/// This class is responsible for sending live event messages to the engine
/// for a track's live event provider node.
class LiveEventManager {
  final ProjectModel project;

  LiveEventManager(this.project);

  Id? _getLiveEventProviderNodeId(Id trackId) {
    final track = project.tracks[trackId];
    return track?.liveEventProviderNodeId;
  }

  void noteOn({
    required Id trackId,
    required int pitch,
    required double velocity,
    required double pan,
  }) {
    if (!project.engine.isRunning) return;

    final liveEventProviderNodeId = _getLiveEventProviderNodeId(trackId);
    if (liveEventProviderNodeId == null) return;

    project.engine.processingGraphApi.sendLiveEvent(
      liveEventProviderNodeId,
      LiveEventRequestNoteOnEvent(pitch: pitch, velocity: velocity, pan: pan),
    );
  }

  void noteOff({required Id trackId, required int pitch}) {
    if (!project.engine.isRunning) return;

    final liveEventProviderNodeId = _getLiveEventProviderNodeId(trackId);
    if (liveEventProviderNodeId == null) return;

    project.engine.processingGraphApi.sendLiveEvent(
      liveEventProviderNodeId,
      LiveEventRequestNoteOffEvent(pitch: pitch),
    );
  }
}
