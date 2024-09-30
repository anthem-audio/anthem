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
import 'package:anthem_codegen/annotations.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Cache of ModelClassInfo instances.
///
/// This map is used to cache class parsing. If we have a reference loop, e.g.
/// class A has a field of type B, and class B has a field of type A, then this
/// prevents an infinite loop in the parser.
Map<ClassElement, ModelClassInfo> _modelClassInfoCache = {};

/// Clears the cache for model items.
///
/// Because classes outside of the current library are sometimes parsed
/// incorrectly, we cannot keep the cache between runs. The build runner creates
/// a single continuous build script that will reuse global variables like this,
/// so we need a way to clear out the cache to make sure that it is fresh for
/// each file.
void cleanModelClassInfoCache() {
  _modelClassInfoCache = {};
}

/// This class contains info about a given Dart model class. It is used during
/// code generation to pre-process info about a model class that will be used
/// across the code generators.
class ModelClassInfo {
  LibraryReader libraryReader;
  ClassElement annotatedClass;

  ClassElement? _baseClass;

  /// Represents the base class for this model class, e.g. `_MyClass` in the
  /// following case:
  ///
  /// ```dart
  /// class MyClass extends _MyClass with _$MyClassAnthemModelMixin {
  ///   ...
  /// }
  ///
  /// class _MyClass {
  ///   ...
  /// }
  /// ```
  ///
  /// This is nullable because sometimes the Dart analyzer can't find the base
  /// class for model classes that are not in the library of the file currently
  /// being parsed.
  ///
  /// This is not an issue because we don't need the base class in this case:
  ///
  /// File being parsed:
  ///
  /// ```dart
  /// @AnthemModel.all()
  /// class SomeClass extends _SomeClass with _$SomeClassAnthemModelMixin {
  ///   ...
  /// }
  ///
  /// // We can *always* find this, because it's in the file currently being
  /// // processed by the builder
  /// class _SomeClass {
  ///   // We will try to parse this into a ModelClassInfo as well
  ///   SomeOtherClass otherClass;
  ///   ...
  /// }
  /// ```
  ///
  /// Some file that is imported by the file being parsed:
  ///
  /// ```dart
  /// @AnthemModel.all()
  /// class SomeOtherClass extends _SomeOtherClass with _$SomeOtherClassAnthemModelMixin {
  ///   ...
  /// }
  ///
  /// // Randomly, the analyzer will fail to find this class. This is fine,
  /// // because when the build package is processing this file, it will always
  /// // find this class.
  /// class _SomeOtherClass {
  ///   ...
  /// }
  /// ```
  ClassElement get baseClass {
    if (_baseClass == null) {
      final String invalidSetupHelp =
          '''Base class not found for ${annotatedClass.name}.

Model items in Anthem must have a super class with a mixin, and a matching base class:

class MyModel extends _MyModel with _\$MyModelAnthemModelMixin;

class _MyModel {
  // ...
};''';

      log.warning(invalidSetupHelp);

      throw Exception();
    }

    return _baseClass!;
  }

  /// Map of field names to their field definitions and types.
  Map<String, ModelFieldInfo> fields = {};

  late bool isSealed;
  List<SealedSubclassInfo> sealedSubclasses = [];

  factory ModelClassInfo(
      LibraryReader libraryReader, ClassElement annotatedClass) {
    return _modelClassInfoCache[annotatedClass] ??
        ModelClassInfo._create(libraryReader, annotatedClass);
  }

  ModelClassInfo._create(this.libraryReader, this.annotatedClass) {
    // Find matching base class for the library class

    final libraryAndImportedClasses = [
      libraryReader.classes,
      libraryReader.element.importedLibraries
          .map((lib) => LibraryReader(lib).classes)
          .expand((e) => e)
    ].expand((e) => e);

    _baseClass = libraryAndImportedClasses
        .where((e) => e.name == '_${annotatedClass.name}')
        .firstOrNull;

    // The code below just doesn't work. I think it's because the mixin isn't
    // defined, so while it exists from a lexing standpoint, the analyzer
    // doesn't find a matching mixin declaration and so it doesn't put it the
    // list.

    // final hasClassMixin = annotatedClass.mixins
    //     .any((m) => m.getDisplayString() == '_\$AnthemModelMixin');

    // if (!hasClassMixin) {
    //   log.warning(
    //       'Mixin not found for ${annotatedClass.name}.\n\n$invalidSetupHelp');
    //   continue;
    // }

    for (final field in _baseClass?.fields ?? []) {
      // If the field doesn't have a setter, it's not something we can
      // deserialize, so we won't include it. This can happen if the field is
      // final, or if the field is a getter.
      if (field.setter == null) continue;

      if (_skipAll(field)) continue;

      fields[field.name] = ModelFieldInfo(
        fieldElement: field,
        libraryReader: libraryReader,
        annotatedClass: annotatedClass,
      );
    }

    isSealed = annotatedClass.isSealed;

    final List<ClassElement> subclasses = [];

    for (var element in libraryReader.classes) {
      if (element.supertype?.element == annotatedClass) {
        subclasses.add(element);
      }
    }

    for (final subclass in subclasses) {
      sealedSubclasses.add(SealedSubclassInfo(subclass, this));
    }

    _modelClassInfoCache[annotatedClass] = this;
  }
}

class SealedSubclassInfo {
  ClassElement subclass;
  Map<String, ModelFieldInfo> fields = {};
  String get name => subclass.name;

  SealedSubclassInfo(this.subclass, ModelClassInfo baseClassInfo) {
    for (final field in subclass.fields) {
      // If the field doesn't have a setter, it's not something we can
      // deserialize, so we won't include it. This can happen if the field is
      // final, or if the field is a getter.
      if (field.setter == null) continue;

      if (_skipAll(field)) continue;

      fields[field.name] = ModelFieldInfo(
        fieldElement: field,
        libraryReader: baseClassInfo.libraryReader,
        annotatedClass: subclass,
      );
    }
  }
}

/// Represents a parsed field in an Anthem model.
class ModelFieldInfo {
  final FieldElement fieldElement;
  final ModelType typeInfo;
  final bool isObservable;

  ModelFieldInfo({
    required this.fieldElement,
    required LibraryReader libraryReader,
    required ClassElement annotatedClass,
  })  : typeInfo =
            getModelType(fieldElement.type, libraryReader, annotatedClass),
        isObservable = (() {
          final hideAnnotation = const TypeChecker.fromRuntime(AnthemObservable)
              .firstAnnotationOf(fieldElement);

          if (hideAnnotation == null) return false;

          return true;
        })();
}

/// Returns true if the field should be skipped during code generation, based on
/// the @Hide annotation.
bool _skipAll(FieldElement field) {
  final hideAnnotation =
      const TypeChecker.fromRuntime(Hide).firstAnnotationOf(field);

  if (hideAnnotation == null) return false;

  final hide = Hide(
    serialization:
        hideAnnotation.getField('serialization')?.toBoolValue() ?? false,
    cpp: hideAnnotation.getField('cpp')?.toBoolValue() ?? false,
  );

  final observableAnnotation =
      const TypeChecker.fromRuntime(AnthemObservable).firstAnnotationOf(field);

  return observableAnnotation == null && hide.serialization && hide.cpp;
}
