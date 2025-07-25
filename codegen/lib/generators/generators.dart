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

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'dart/anthem_model_generator.dart';
import 'cpp/cpp_model_builder.dart';
import 'debug_engine_path_generator.dart';

Builder anthemDartModelGeneratorBuilder(BuilderOptions options) =>
    SharedPartBuilder([
      AnthemModelGenerator(options),
    ], 'anthem_model_generator');

Builder cppModelBuilder(BuilderOptions options) => CppModelBuilder();

Builder debugEnginePathGeneratorBuilder(BuilderOptions options) =>
    DebugEnginePathGeneratorBuilder();
