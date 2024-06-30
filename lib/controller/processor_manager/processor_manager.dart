/*
  Copyright (C) 2024 Joshua Wade

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

import 'package:anthem/engine_api/engine.dart';
import 'package:flutter/foundation.dart';

/// Manages processors that can be created in the engine's processing graph.
/// This includes internal processors (synths, effects, control generators,
/// etc.), but it also includes code to manage external plugins.
class ProcessorManager {
  ProcessorManager._internal();

  /// Validates the given processor against an engine. This should be run every
  /// time a processor is added in the engine to verify that the UI and engine
  /// are in alignment.
  void validateProcessor(Engine engine, String processorId) {
    if (!kDebugMode) return;

    if (engine.engineState != EngineState.running) {
      throw AssertionError(
          'Engine must be running to validate the processor list.');
    }

    // TODO: Fill this in
  }
}

final processorManager = ProcessorManager._internal();
