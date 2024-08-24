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
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Cache of ModelClassInfo instances. Allows us to look up types when generating the type
/// graph.
Map<(LibraryElement, ClassElement), ModelClassInfo> _modelClassInfoCache = {};

/// This class contains info about a given Dart model class. It is used during
/// code generation to pre-process info about a model class that will be used
/// across the code generators.
class ModelClassInfo {
  LibraryReader libraryReader;
  ClassElement annotatedClass;
  late ClassElement baseClass;

  Map<String, ModelType> fields = {};

  factory ModelClassInfo(
      LibraryReader libraryReader, ClassElement annotatedClass) {
    final cacheItem =
        _modelClassInfoCache[(annotatedClass.library, annotatedClass)];

    // if (cacheItem == null) {
    //   print('cache miss');
    // } else {
    //   print('cache hit');
    // }

    return cacheItem ?? ModelClassInfo._create(libraryReader, annotatedClass);
  }

  ModelClassInfo._create(this.libraryReader, this.annotatedClass) {
    // Find matching base class for the library class

    final baseClassOrNull = libraryReader.classes
        .where((e) => e.name == '_${annotatedClass.name}')
        .firstOrNull;

    const String invalidSetupHelp =
        '''Model items in Anthem must have a super class with a mixin, and a matching base class:

class MyModel extends _MyModel with _\$MyModelAnthemModelMixin;

class _MyModel {
  // ...
};''';

    if (baseClassOrNull == null) {
      final err =
          'Base class not found for ${annotatedClass.name}.\n\n$invalidSetupHelp';

      log.warning(err);
      throw Exception();
    }

    baseClass = baseClassOrNull;

    // The code below just doesn't work. I think it's because the mixin doesn't
    // exist, so while it exists from a lexing standpoint, the analyzer doesn't
    // find a matching mixin declaration and so it doesn't put it the list.

    // final hasClassMixin = annotatedClass.mixins
    //     .any((m) => m.getDisplayString() == '_\$AnthemModelMixin');

    // if (!hasClassMixin) {
    //   log.warning('Mixin length: ${annotatedClass.mixins.length}');
    //   log.warning(
    //       'Mixins are: ${annotatedClass.mixins.map((type) => type.getDisplayString()).join(', ')}');
    //   log.warning(
    //       'Mixin not found for ${annotatedClass.name}.\n\n$invalidSetupHelp');
    //   continue;
    // }

    for (final field in baseClass.fields) {
      fields[field.name] =
          getModelType(field.type, libraryReader, annotatedClass);
    }

    _modelClassInfoCache[(annotatedClass.library, annotatedClass)] = this;
  }
}
