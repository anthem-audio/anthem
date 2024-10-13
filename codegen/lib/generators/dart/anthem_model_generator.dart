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
      final annotationFromAnalyzer = const TypeChecker.fromRuntime(AnthemModel)
          .firstAnnotationOf(libraryClass);

      // If there is no annotation on this class, don't do anything
      if (annotationFromAnalyzer == null) continue;

      // Read properties from @AnthemModel() annotation

      final anthemModelAnnotation = AnthemModel(
        serializable:
            annotationFromAnalyzer.getField('serializable')?.toBoolValue() ??
                false,
        generateCpp:
            annotationFromAnalyzer.getField('generateCpp')?.toBoolValue() ??
                false,
        generateModelSync: annotationFromAnalyzer
                .getField('generateModelSync')
                ?.toBoolValue() ??
            false,
      );

      final context = ModelClassInfo(library, libraryClass);

      result +=
          'mixin _\$${libraryClass.name}AnthemModelMixin on ${context.baseClass.name}${anthemModelAnnotation.generateModelSync ? ', AnthemModelBase' : ''} {\n';

      if (anthemModelAnnotation.serializable) {
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
        classHasModelSyncCode: anthemModelAnnotation.generateModelSync,
      );
      if (anthemModelAnnotation.generateModelSync) {
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
      switch (fieldInfo.typeInfo) {
        case ListModelType listType:
          setter += _generateListObserver(
            fieldName: fieldName,
            isNullable: fieldInfo.typeInfo.isNullable,
            toJsonConverter: (field, [firstIterationAlwaysNullable]) =>
                _convertToJson(field, listType.itemType,
                    useQuestionForNotNullable:
                        firstIterationAlwaysNullable ?? false),
          );
          break;
        case MapModelType mapType:
          setter += _generateMapObserver(
            fieldName: fieldName,
            isNullable: fieldInfo.typeInfo.isNullable,
            // Hack - regular string keys are sometimes coming through as unknown
            // model types, and I don't feel like tracking it down now. This
            // should work for now.
            keyToJsonConverter: (field) => field,
            valueToJsonConverter: (field) => _convertToJson(
                field, mapType.valueType,
                useExclamationForNotNullable: true),
          );
          break;
        case _:
          // If the field is a custom model type, we need to tell it about its
          // parent.
          if (fieldInfo.typeInfo is CustomModelType ||
              fieldInfo.typeInfo is UnknownModelType) {
            setter += '''
super.$fieldName$typeQ.setParentProperties(
  parent: this,
  parentFieldName: '$fieldName',
  fieldType: FieldType.raw,
);
''';
          }

          final valueGetter = switch (fieldInfo.typeInfo) {
            ListModelType() || MapModelType() => throw Exception(
                'As originally designed, this should not be possible. This is a bug.'),
            StringModelType() ||
            IntModelType() ||
            DoubleModelType() ||
            NumModelType() ||
            BoolModelType() =>
              'value',
            EnumModelType() => 'value$typeQ.name',
            ColorModelType() =>
              "{ 'a': value.alpha, 'r': value.red, 'g': value.green, 'b': value.blue }",
            CustomModelType() || UnknownModelType() => 'value$typeQ.toJson()',
          };

          // Regardless of the type, we need to notify that this field was
          // changed.
          setter += '''
notifyFieldChanged(
  operation: RawFieldUpdate(
    fieldName: '$fieldName',
    fieldType: FieldType.raw,
    newValue: $valueGetter,
  ),
);
''';
          break;
      }
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

    switch (fieldInfo.typeInfo) {
      case ListModelType listType:
        // When observing the list, we get a set of changes in each callback.
        // For any elements added, we need to rewrite the elements provided so
        // that they're in a serialized form before sending them to be handled.
        // This is because there is no generic interface for serialization.
        result += _generateListObserver(
          fieldName: fieldName,
          isNullable: fieldInfo.typeInfo.isNullable,
          toJsonConverter: (field, [firstIterationAlwaysNullable]) =>
              _convertToJson(field, listType.itemType,
                  useQuestionForNotNullable:
                      firstIterationAlwaysNullable ?? false),
        );
        break;
      case MapModelType mapType:
        result += _generateMapObserver(
          fieldName: fieldName,
          isNullable: fieldInfo.typeInfo.isNullable,
          // Hack - regular string keys are sometimes coming through as unknown
          // model types, and I don't feel like tracking it down now. This
          // should work for now.
          keyToJsonConverter: (field) => field,
          valueToJsonConverter: (field) => _convertToJson(
              field, mapType.valueType,
              useExclamationForNotNullable: true),
        );
        break;
      case CustomModelType():
        result += '''
super.$fieldName$typeQ.setParentProperties(
  parent: this,
  parentFieldName: '$fieldName',
  fieldType: FieldType.raw,
);
''';
        break;
      case _:
        break;
    }
  }

  result += 'isInitialized = true;';

  result += '}\n';

  return result;
}

String _generateListObserver({
  required String fieldName,
  required bool isNullable,
  required String Function(String, [bool? firstIterationAlwaysNullable])
      toJsonConverter,
}) {
  final typeQ = isNullable ? '?' : '';

  return '''
super.$fieldName$typeQ.observe(
  (change) {
    final newChange = AnthemListChange(
      elementChanges: change.elementChanges?.map((elementChange) {
        return AnthemElementChange(
          index: elementChange.index,
          type: elementChange.type,
          newValueSerialized: ${toJsonConverter('elementChange.newValue', true)},
        );
      }).toList(),

      rangeChanges: change.rangeChanges?.map((rangeChange) {
        return AnthemRangeChange(
          index: rangeChange.index,
          newValuesSerialized: rangeChange.newValues?.map((e) => ${toJsonConverter('e')}).toList(),
          numItemsRemoved: rangeChange.oldValues?.length ?? 0,
        );
      }).toList(),
    );

    handleListUpdate(
      fieldName: '$fieldName',
      list: super.$fieldName,
      change: newChange,
    );
  },
  fireImmediately: true,
);
''';
}

String _generateMapObserver({
  required String fieldName,
  required bool isNullable,
  required String Function(String) keyToJsonConverter,
  required String Function(String) valueToJsonConverter,
}) {
  final typeQ = isNullable ? '?' : '';

  return '''
super.$fieldName$typeQ.observe(
  (change) {
    if (change.newValue != null) {
      if (change.newValue is AnthemModelBase) {
        (change.newValue as AnthemModelBase).setParentProperties(
          parent: this,
          parentFieldName: '$fieldName',
          fieldType: FieldType.map,
          key: change.key,
        );
      }

      notifyFieldChanged(
        operation: MapPut(
          fieldName: '$fieldName',
          fieldType: FieldType.map,
          key: ${keyToJsonConverter('change.key')},
          value: ${valueToJsonConverter('change.newValue')},
        ),
      );
    } else {
      notifyFieldChanged(
        operation: MapRemove(
          fieldName: '$fieldName',
          fieldType: FieldType.map,
          key: change.key,
        ),
      );
    }
  },
  fireImmediately: true,
);
''';
}

String _convertToJson(String field, ModelType type,
    {bool useExclamationForNotNullable = false,
    bool useQuestionForNotNullable = false}) {
  final typeQ = type.isNullable || useQuestionForNotNullable
      ? '?'
      : useExclamationForNotNullable
          ? '!'
          : '';

  return switch (type) {
    StringModelType() => field,
    IntModelType() => field,
    DoubleModelType() => field,
    NumModelType() => field,
    BoolModelType() => field,
    EnumModelType() => '$field$typeQ.name',
    ListModelType() =>
      '$field$typeQ.map((e) => ${_convertToJson('e', type.itemType)}).toList()',
    MapModelType() =>
      '$field$typeQ.map((key, value) => MapEntry(${_convertToJson('key', type.keyType)}, ${_convertToJson('value', type.valueType)}))',
    ColorModelType() =>
      "{ 'a': $field.alpha, 'r': $field.red, 'g': $field.green, 'b': $field.blue }",
    CustomModelType() => '$field$typeQ.toJson()',
    UnknownModelType() => '$field$typeQ.toJson()',
  };
}
