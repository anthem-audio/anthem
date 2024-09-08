/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

class ProjectApi {
  final Engine _engine;

  ProjectApi(this._engine);

  /// Creates a new arrangement, which maps to an `Edit` in Tracktion Engine.
  /// Returns a pointer to the Tracktion edit object within the engine process.
  ///
  /// The UI is responsible for cleaning up this memory.
  Future<int> addArrangement() async {
    final id = _engine._getRequestId();

    final request = AddArrangementRequest(id: id);

    final response =
        (await _engine._request(id, request)) as AddArrangementResponse;

    return response.editId;
  }

  /// Removes an arrangement with the given `Edit` pointer.
  ///
  /// See [addArrangement].
  Future<void> deleteArrangement(int editId) {
    final id = _engine._getRequestId();

    final request = DeleteArrangementRequest(id: id, editId: editId);

    return _engine._request(id, request);
  }

  Future<void> noteOn({
    int channel = 1,
    required int note,
    double velocity = 0.5,
    required int editId,
  }) {
    final id = _engine._getRequestId();

    final request = LiveNoteOnRequest(
      id: id,
      editId: editId,
      channel: channel,
      note: note,
      velocity: velocity,
    );

    return _engine._request(id, request);
  }

  Future<void> noteOff({
    int channel = 1,
    required int note,
    required int editId,
  }) {
    final id = _engine._getRequestId();

    final request = LiveNoteOffRequest(
      id: id,
      editId: editId,
      channel: channel,
      note: note,
    );

    return _engine._request(id, request);
  }
}
