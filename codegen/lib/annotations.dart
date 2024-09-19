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

/// An annotation that triggers code generation for Anthem models.
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

  /// Constructor for [AnthemModel].
  ///
  /// See the documentation above for more info.
  const AnthemModel({this.serializable = false, this.generateCpp = false});

  /// Constructor for [AnthemModel], which enables all options.
  ///
  /// See the documentation above for more info.
  const AnthemModel.all() : this(serializable: true, generateCpp: true);
}

/// An annotation that triggers the Anthem code generator to create a module
/// file in C++.
///
/// When a library is tagged with this annotation, a matching `.h` file will be
/// generated in the engine's `generated` folder. This generated header will
/// `#include` any generated `.h` files that match the `.dart` files exported by
/// this library.
///
/// **If there are model files that import other model files, a module file is
/// required for the C++ model to be generated correctly.** This is because we
/// need to put forward declarations in the generated C++ file to prevent issues
/// with include order and allows circular references between model files.
///
/// Note that this only works if the exported files have classes tagged with
/// `AnthemModel(generateCpp: true)`.
///
/// ### Example
///
/// `my_module.dart`:
/// ```dart
/// @GenerateCppModuleFile()
/// library models;
///
/// export 'first_model.dart';
/// export 'subfolder/second_model.dart';
/// export 'non_model_file.dart';
/// ```
///
/// `first_model.dart`:
/// ```dart
/// @AnthemModel(serializable: true, generateCpp: true)
/// class MyFirstModel {
///   // ...
/// }
///
/// class UntaggedClass {}
/// ```
///
/// `subfolder/second_model.dart`:
/// ```dart
/// import '../first_model.dart';
///
/// @AnthemModel(serializable: true, generateCpp: true)
/// class MySecondModel {
///   MyFirstModel firstModel;
///   // ...
/// }
/// ```
///
/// Given this setup, the following C++ module file will be generated:
///
/// ```cpp
/// #pragma once
///
/// enum class MyFirstModel;
/// enum class MySecondModel;
///
/// // If there are any sealed classes, using statements will show up here.
///
/// #include 'first_model.h'
/// #include 'subfolder/second_model.h'
/// ```
class GenerateCppModuleFile {
  /// Constructor for [GenerateCppModuleFile].
  ///
  /// See the documentation above for more info.
  const GenerateCppModuleFile();
}
