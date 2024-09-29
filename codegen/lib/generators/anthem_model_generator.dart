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

import 'dart:async';

import 'package:anthem_codegen/generators/json_deserialize_generator.dart';
import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'json_serialize_generator.dart';

/// Provides code generation for Anthem models.
///
/// Anthem models must be defined like this:
///
/// ```dart
/// // ...
///
/// part 'my_model.g.dart'
///
/// @AnthemModel.all()
/// class MyModel extends _MyModel with _$MyModelAnthemModelMixin;
///
/// class _MyModel {
///   // ...
/// }
/// ```
class AnthemModelGenerator extends Generator {
  final BuilderOptions options;

  AnthemModelGenerator(this.options);

  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    var result = '';

    // Looks for @AnthemModel on each class in the file, and generates the
    // appropriate code
    for (final libraryClass in library.classes) {
      final annotation = libraryClass.metadata
          .where(
            (annotation) =>
                annotation.element?.enclosingElement?.name == 'AnthemModel',
          )
          .firstOrNull;

      // If there is no annotation on this class, don't do anything
      if (annotation == null) continue;

      // Using ConstantReader to read annotation properties
      final reader = ConstantReader(annotation.computeConstantValue());

      // Read properties from @AnthemModel() annotation

      bool serializable;

      if (reader.isNull) {
        log.severe(
            '[Anthem codegen] Annotation reader is null for class ${libraryClass.name}. This is either a bug, or we need better error messages here.');
        continue;
      } else {
        // Reading properties of the annotation
        serializable = reader.read('serializable').literalValue as bool;
      }

      final context = ModelClassInfo(library, libraryClass);

      result +=
          'mixin _\$${libraryClass.name}AnthemModelMixin on ${context.baseClass.name} {\n';

      if (serializable) {
        result += generateJsonSerializationCode(context: context);
        result += '\n';
        result += generateJsonDeserializationCode(context: context);
      }

      result += '}\n';
    }

    // The cache for parsed classes persists across files, so we need to clear
    // it for each file.
    cleanModelClassInfoCache();

    return result;
  }
}
