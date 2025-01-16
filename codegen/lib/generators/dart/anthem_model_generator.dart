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

import 'dart:async';

import 'package:anthem_codegen/generators/dart/serialize_generators.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:anthem_codegen/include/annotations.dart';
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
    if (fieldInfo.isModelConstant ||
        (!fieldInfo.isObservable && !shouldGenerateModelSync)) {
      continue;
    }

    // If model sync code is being generated, we need to validate that this
    // field is using the custom collection types.
    if (shouldGenerateModelSync) {
      if (fieldInfo.typeInfo case ListModelType typeInfo) {
        if (typeInfo.collectionType != CollectionType.anthemObservable) {
          throw Exception(
              'Synced models must use AnthemObservableList, but $fieldName is using ${typeInfo.collectionType} instead.');
        }
      }

      if (fieldInfo.typeInfo case MapModelType typeInfo) {
        if (typeInfo.collectionType != CollectionType.anthemObservable) {
          throw Exception(
              'Synced models must use AnthemObservableMap, but $fieldName is using ${typeInfo.collectionType} instead.');
        }
      }

      if (fieldInfo.typeInfo case UnionModelType typeInfo) {
        // This code checks through the possible subtypes to check for lists and
        // maps as well. Note that a recursive check is not needed, because
        // union types can only exist as the type of a field, and not as a
        // template type, such as List<UnionType>.
        for (final subtype in typeInfo.subTypes) {
          if (subtype is ListModelType) {
            if (subtype.collectionType != CollectionType.anthemObservable) {
              throw Exception(
                  'Synced models must use AnthemObservableList, but $fieldName is using ${subtype.collectionType} instead.');
            }
          }

          if (subtype is MapModelType) {
            if (subtype.collectionType != CollectionType.anthemObservable) {
              throw Exception(
                  'Synced models must use AnthemObservableMap, but $fieldName is using ${subtype.collectionType} instead.');
            }
          }
        }
      }
    }

    // Getter

    final typeQ = fieldInfo.typeInfo.isNullable ? '?' : '';

    result += '@override\n';
    result += '// ignore: duplicate_ignore\n';
    result += '// ignore: unnecessary_overrides\n';
    result += '${fieldInfo.typeInfo.dartName}$typeQ get $fieldName {\n';
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
          fieldInfo.typeInfo is UnknownModelType ||
          fieldInfo.typeInfo is ListModelType ||
          fieldInfo.typeInfo is MapModelType) {
        setter += '''
super.$fieldName$typeQ.setParentProperties(
  parent: this,
  fieldName: '$fieldName',
  fieldType: FieldType.raw,
);
''';
      } else if (fieldInfo.typeInfo case UnionModelType typeInfo) {
        var first = true;
        for (final subtype in typeInfo.subTypes) {
          setter += '''
var setterReceivedValidType = false;
${first ? 'else ' : ''}if (value is ${subtype.dartName}) {
  setterReceivedValidType = true;
''';
          if (subtype is CustomModelType ||
              subtype is UnknownModelType ||
              subtype is ListModelType ||
              subtype is MapModelType) {
            setter += '''
  (value as ${subtype.dartName}).setParentProperties(
    parent: this,
    fieldName: '$fieldName',
    fieldType: FieldType.raw,
  );
''';
          }
          setter += '''
}

if (!setterReceivedValidType) {
  throw Exception('Invalid type for field $fieldName. Got value of type \${field.runtimeType}, but expected one of: ${typeInfo.subTypes.map((subtype) => subtype.dartName).join(', ')}.');
}
''';
          first = false;
        }
      }

      final valueGetter = createSerializerForField(
        type: fieldInfo.typeInfo,
        accessor: 'value',
        alwaysIncludeEngineOnlyFields: true,
      );

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
    result += 'set $fieldName(${fieldInfo.typeInfo.dartName}$typeQ value) {\n';
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
///
/// This should only be called if the model is a synced model.
String _generateInitFunction({required ModelClassInfo context}) {
  var result = '@override\n';

  result += 'void setParentPropertiesOnChildren() {\n';

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

  result += '}\n';

  return result;
}
