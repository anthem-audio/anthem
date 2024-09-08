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

/// This is an annotation that triggers code generation for Anthem models.
///
/// Usage:
///
/// ```dart
/// @AnthemModel.all()
/// class MyModel {
///   // ...
/// }
///
/// @AnthemModel(generateCpp: true, serializable: true)
/// class MyIpcMessage {
///   // ...
/// }
/// ```
///
/// Per-class code generation in Anthem has a number of features that can be
/// enabled and disabled.
///
/// For example, the application data model is automatically synced with the
/// engine, and this code generation enables that. This involves serialization,
/// creating matching C++ structs for each model item that can be deserialized
/// from JSON, and generating code on both sides to automatically create and
/// synchronize a model in the engine that matches the UI model.
///
/// On the other hand, message classes for IPC only need the first two, and do
/// not need the automatic model synchronization.
///
/// See above for an example of using the decorator in both cases.
class AnthemModel {
  final bool serializable;
  final bool generateCpp;

  const AnthemModel({this.serializable = false, this.generateCpp = false});

  const AnthemModel.all() : this(serializable: true, generateCpp: true);
}
