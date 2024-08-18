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

/// This library contains code generation for Anthem models.
///
/// Code generation is used for serializing the project model to and from JSON.
/// It is also used to serialize and deserialize message objects when
/// communicating with the engine.
///
/// In addition to these more straightforward uses, code generation is also used
/// to generate C++ models that match the Dart models, and is used to generate
/// Dart code and C++ code to automatically synchronize the two model instances.
library codegen;

export 'generators/generators.dart';
