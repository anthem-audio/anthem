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

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'json_generator.dart';

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

      // Find matching base class for the library class

      final baseClass = library.classes
          .where((e) => e.name == '_${libraryClass.name}')
          .firstOrNull;

      const String invalidSetupHelp =
          '''Model items in Anthem must have a super class with a mixin, and a matching base class:

class MyModel extends _MyModel with _\$MyModelAnthemModelMixin;

class _MyModel {
  // ...
};''';

      if (baseClass == null) {
        log.severe(
            'Base class not found for ${libraryClass.name}.\n\n$invalidSetupHelp');
        continue;
      }

      // The code below just doesn't work, and I have no idea why.

      // final hasClassMixin = libraryClass.mixins
      //     .any((m) => m.getDisplayString() == '_\$AnthemModelMixin');

      // if (!hasClassMixin) {
      //   log.severe('Mixin length: ${libraryClass.mixins.length}');
      //   log.severe(
      //       'Mixins are: ${libraryClass.mixins.map((type) => type.getDisplayString()).join(', ')}');
      //   log.severe(
      //       'Mixin not found for ${libraryClass.name}.\n\n$invalidSetupHelp');
      //   continue;
      // }

      result += '// Annotation found on class: ${libraryClass.name}\n';

      result += 'mixin _\$${libraryClass.name}AnthemModelMixin {\n';

      if (serializable) {
        result += generateJsonSerializationCode(
          publicClass: libraryClass,
          privateBaseClass: baseClass,
        );
      }

      result += '}\n';
    }

    return result;
  }
}
