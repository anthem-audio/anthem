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

/// An annotation that triggers code generation for Anthem models.
///
/// Usage:
///
/// ```dart
/// @AnthemModel()
/// class MyModel {
///   // ...
/// }
///
/// @AnthemModel.ipc()
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
  final bool generateModelSync;
  final bool generateCppWrapperClass;
  final String? cppBehaviorClassName;
  final String? cppBehaviorClassIncludePath;

  /// Constructor for [AnthemModel].
  ///
  /// See the documentation above for more info.
  const AnthemModel({
    this.serializable = false,
    this.generateCpp = false,
    this.generateModelSync = false,
    this.generateCppWrapperClass = false,
    this.cppBehaviorClassName,
    this.cppBehaviorClassIncludePath,
  });

  /// Constructor for [AnthemModel], which enables options necessary for model
  /// generation and syncing with C++.
  ///
  /// See the documentation above for more info.
  const AnthemModel.syncedModel({
    String? cppBehaviorClassName,
    String? cppBehaviorClassIncludePath,
  }) : this(
         serializable: true,
         generateCpp: true,
         generateModelSync: true,
         generateCppWrapperClass: true,
         cppBehaviorClassName: cppBehaviorClassName,
         cppBehaviorClassIncludePath: cppBehaviorClassIncludePath,
       );

  /// Constructor for [AnthemModel], which enables options necessary for IPC
  /// messages.
  ///
  /// See the documentation above for more info.
  const AnthemModel.ipc()
    : this(
        serializable: true,
        generateCpp: true,
        generateModelSync: false,
        generateCppWrapperClass: false,
      );
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

/// An annotation that marks a class to be hidden from serialization or C++
/// generation.
class Hide {
  final bool serialization;
  final bool cpp;

  const Hide({this.serialization = false, this.cpp = false});
  const Hide.all() : this(serialization: true, cpp: true);
}

/// Shorthand for @Hide.all()
const hide = Hide.all();

/// Shorthand for @Hide(serialization: true) - hides the field from
/// serialization, but still generates C++ code and model sync code for it.
const hideFromSerialization = Hide(serialization: true);

/// An annotation that marks a field as a MobX observable.
///
/// This must be used instead of `@observable` if Anthem is also generating
/// model synchronization code for the given model. This should provide
/// identical behavior to MobX's `@observable`.
class AnthemObservable {
  const AnthemObservable();
}

/// An annotation that marks a field as a MobX observable.
///
/// This must be used instead of `@observable` if Anthem is also generating
/// model synchronization code for the given model. This should provide
/// identical behavior to MobX's `@observable`.
const anthemObservable = AnthemObservable();

/// This annotation is used to mark an enum as an Anthem enum. This will allow
/// it to generate an equivalent `enum class` in C++.
class AnthemEnum {
  const AnthemEnum();
}

/// This annotation is used to mark a field as a union. This allows the correct
/// serialization and deserialization of dynamic fields, and as such allows for
/// a crude form of polymorphism in the model.
///
/// Note that we support sealed classes for serialization and use it for IPC,
/// but not for model sync due to the complexity. So, this is the primary way to
/// do polymorphism in the model.
///
/// Unions are defined like so:
/// ```dart
/// @Union([FirstType, SecondType])
/// Object unionField;
/// ```
class Union {
  final List<Type> types;

  const Union(this.types);
}
