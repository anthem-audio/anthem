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

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// This class contains info about a given Dart model class. It is used during
/// code generation to pre-process info about a model class that will be used
/// across the code generators.
class ModelClassInfo {
  LibraryReader libraryReader;
  ClassElement annotatedClass;
  late ClassElement baseClass;

  ModelClassInfo(this.libraryReader, this.annotatedClass) {
    // Find matching base class for the library class

    final baseClass = libraryReader.classes
        .where((e) => e.name == '_${annotatedClass.name}')
        .firstOrNull;

    const String invalidSetupHelp =
        '''Model items in Anthem must have a super class with a mixin, and a matching base class:

class MyModel extends _MyModel with _\$MyModelAnthemModelMixin;

class _MyModel {
  // ...
};''';

    if (baseClass == null) {
      final err =
          'Base class not found for ${annotatedClass.name}.\n\n$invalidSetupHelp';

      log.severe(err);
      throw Exception();
    }

    // The code below just doesn't work, and I have no idea why.

    // final hasClassMixin = annotatedClass.mixins
    //     .any((m) => m.getDisplayString() == '_\$AnthemModelMixin');

    // if (!hasClassMixin) {
    //   log.severe('Mixin length: ${annotatedClass.mixins.length}');
    //   log.severe(
    //       'Mixins are: ${annotatedClass.mixins.map((type) => type.getDisplayString()).join(', ')}');
    //   log.severe(
    //       'Mixin not found for ${annotatedClass.name}.\n\n$invalidSetupHelp');
    //   continue;
    // }
  }
}
