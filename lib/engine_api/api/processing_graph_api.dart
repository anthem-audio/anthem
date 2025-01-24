/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

part of 'package:anthem/engine_api/engine.dart';

/// This class is an API for the processing graph in the Anthem Engine. It can
/// be used to add and remove nodes, and to connect and disconnect existing
/// nodes.
class ProcessingGraphApi {
  final Engine _engine;

  ProcessingGraphApi(this._engine);

  /// Compiles the processing graph, and pushes the result to the audio thread.
  ///
  /// Any updates to the topology of the processing graph, e.g. adding or
  /// removing nodes or modifying connections, are done first by modifying the
  /// model. When ready, this method can be called to compile an updated set of
  /// processing instructions and push them to the audio thread.
  Future<void> compile() async {
    final id = _engine._getRequestId();

    final request = CompileProcessingGraphRequest(
      id: id,
    );

    final response =
        (await _engine._request(request)) as CompileProcessingGraphResponse;

    if (response.success) {
      return;
    } else {
      throw Exception('compile(): engine returned an error: ${response.error}');
    }
  }
}
