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

import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem_codegen/generators/dart/json_deserialize_generator.dart';
import 'package:anthem_codegen/generators/dart/mobx_generator.dart';
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
/// @AnthemModel.syncedModel()
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
      final annotationFromAnalyzer = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(libraryClass);

      // If there is no annotation on this class, don't do anything
      if (annotationFromAnalyzer == null) continue;

      // Read properties from @AnthemModel() annotation

      final context = ModelClassInfo(library, libraryClass);

      result +=
          'mixin _\$${libraryClass.name}AnthemModelMixin on ${context.baseClass.name}${context.annotation!.generateModelSync ? ', AnthemModelBase' : ''} {\n';

      if (context.annotation!.serializable) {
        result += '\n  // JSON serialization\n';
        result += '\n';
        result += generateJsonSerializationCode(context: context);
        result += '\n  // JSON deserialization\n';
        result += '\n';
        result += generateJsonDeserializationCode(context: context);
      }
      result += '\n  // MobX atoms\n';
      result += '\n';
      result += generateMobXAtoms(context: context);
      result += '\n  // Getters and setters\n';
      result += '\n';
      result += _generateGettersAndSetters(
        context: context,
        classHasModelSyncCode: context.annotation!.generateModelSync,
      );
      if (context.annotation!.generateModelSync) {
        result += '\n  // Init function\n';
        result += '\n';
        result += _generateInitFunction(context: context);
      }

      result += '}\n';
    }

    // The cache for parsed classes persists across files, so we need to clear
    // it for each file.
    cleanModelClassInfoCache();

    return result;
  }
}

/// Generates getters and setters for model items.
///
/// Note that this will not generate anything for fields in sealed classes.
String _generateGettersAndSetters(
    {required ModelClassInfo context, required bool classHasModelSyncCode}) {
  var result = '';

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    final shouldGenerateModelSync =
        classHasModelSyncCode && fieldInfo.hideAnnotation?.cpp != true;

    // Skip if this field doesn't need a getter/setter
    if (!fieldInfo.isObservable && !shouldGenerateModelSync) {
      continue;
    }

    // Getter

    final typeQ = fieldInfo.typeInfo.isNullable ? '?' : '';

    result += '@override\n';
    result += '// ignore: duplicate_ignore\n';
    result += '// ignore: unnecessary_overrides\n';
    result += '${fieldInfo.typeInfo.name}$typeQ get $fieldName {\n';
    if (fieldInfo.isObservable) {
      result += generateMobXGetter(fieldName, fieldInfo);
    }
    result += 'return super.$fieldName;\n';
    result += '}\n\n';

    // Setter

    var setter = 'super.$fieldName = value;\n';

    if (shouldGenerateModelSync) {
      // If the field is a custom model type, we need to tell it about its
      // parent.
      if (fieldInfo.typeInfo is CustomModelType ||
          fieldInfo.typeInfo is UnknownModelType) {
        setter += '''
super.$fieldName$typeQ.setParentProperties(
  parent: this,
  fieldName: '$fieldName',
  fieldType: FieldType.raw,
);
''';
      }

      final valueGetter = switch (fieldInfo.typeInfo) {
        StringModelType() ||
        IntModelType() ||
        DoubleModelType() ||
        NumModelType() ||
        BoolModelType() =>
          'value',
        EnumModelType() => 'value$typeQ.name',
        ColorModelType() =>
          "{ 'a': value.alpha, 'r': value.red, 'g': value.green, 'b': value.blue }",
        CustomModelType() ||
        UnknownModelType() ||
        ListModelType() ||
        MapModelType() =>
          'value$typeQ.toJson(includeFieldsForEngine: true)',
      };

      // Regardless of the type, we need to notify that this field was
      // changed.
      setter += '''
notifyFieldChanged(
  operation: RawFieldUpdate(
    newValue: $valueGetter,
  ),
  accessorChain: [
    FieldAccessor(
      fieldType: FieldType.raw,
      fieldName: '$fieldName',
    ),
  ],
);
''';
    }

    result += '@override\n';
    result += 'set $fieldName(${fieldInfo.typeInfo.name}$typeQ value) {\n';
    if (fieldInfo.isObservable) {
      result += wrapCodeWithMobXSetter(fieldName, fieldInfo, setter);
    } else {
      result += setter;
    }

    result += '}\n\n';
  }

  return result;
}

/// Generates the init function for the model.
String _generateInitFunction({required ModelClassInfo context}) {
  var result = '';

  result += 'void init() {\n';

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    final typeQ = fieldInfo.typeInfo.isNullable ? '?' : '';

    if (fieldInfo.typeInfo is ListModelType ||
        fieldInfo.typeInfo is MapModelType ||
        fieldInfo.typeInfo is CustomModelType) {
      result += '''
super.$fieldName$typeQ.setParentProperties(
  parent: this,
  fieldName: '$fieldName',
  fieldType: FieldType.raw,
);
''';
    }
  }

  result += 'isInitialized = true;';

  result += '}\n';

  return result;
}
