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
import 'package:anthem/model/generator.dart';

/// Manages live events for a generator.
///
/// This class is responsible for sending live event messages to the engine
/// for a specific generator instance.
class LiveEventManager {
  final GeneratorModel generator;

  LiveEventManager(this.generator);

  void noteOn({
    required int pitch,
    required double velocity,
    required double pan,
  }) {
    generator.project.engine.processingGraphApi.sendLiveEvent(
      generator.liveEventProviderNodeId!,
      LiveEventRequestNoteOnEvent(pitch: pitch, velocity: velocity, pan: pan),
    );
  }

  void noteOff({required int pitch}) {
    generator.project.engine.processingGraphApi.sendLiveEvent(
      generator.liveEventProviderNodeId!,
      LiveEventRequestNoteOffEvent(pitch: pitch),
    );
  }
}
