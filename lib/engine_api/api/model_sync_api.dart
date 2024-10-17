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

part of 'package:anthem/engine_api/engine.dart';

/// Provides an API for syncing the model state between the UI and the engine.
///
/// Anthem uses codegen to generate C++ model classes which match the
/// developer-defined Dart model, including serialization and deserialization
/// mechanisms on both sides. On top of this, the Dart model is observable and
/// produces a stream of changes that can be used to update the engine when the
/// UI model changes.
///
/// This API provides a set of methods for providing these auto-generated state
/// updates to the engine, so that the engine can keep its model in sync with
/// the UI model.
class ModelSyncApi {
  final Engine _engine;

  ModelSyncApi(this._engine);

  /// Initializes the engine model with the given serialized model representation.
  void initModel(String serializedModel) {
    final id = _engine._getRequestId();

    final request = ModelInitRequest(id: id, serializedModel: serializedModel);

    _engine._request(id, request);
  }

  /// Updates the engine model with the given field update.
  void updateModel({
    required FieldUpdateKind updateKind,
    required List<FieldAccess> fieldAccesses,
    required String fieldName,
    String? serializedValue,
    int? listIndex,
    String? serializedMapKey,
  }) {
    final id = _engine._getRequestId();

    final request = ModelUpdateRequest(
      id: id,
      updateKind: updateKind,
      fieldAccesses: fieldAccesses,
      fieldName: fieldName,
      serializedValue: serializedValue,
      listIndex: listIndex,
      serializedMapKey: serializedMapKey,
    );

    _engine._request(id, request);
  }
}