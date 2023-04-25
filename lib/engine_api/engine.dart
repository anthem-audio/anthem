/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/engine_api/engine_connector.dart';

/// Engine class, used for communicating with Tracktion Engine.
///
/// This class manages the IPC connection between the UI and engine processes
/// and provides a higher-level async API to the rest of the UI.
class Engine {
  String id;
  late EngineConnector _engineConnector;

  Engine(this.id) {
    _engineConnector = EngineConnector(id);
  }

  void dispose() {
    _engineConnector.dispose();
  }
}
