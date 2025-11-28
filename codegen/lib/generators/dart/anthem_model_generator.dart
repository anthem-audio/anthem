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

import 'package:anthem_codegen/generators/dart/model_change_generator.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'json_deserialize_generator.dart';
import 'json_serialize_generator.dart';
import 'field_serializers.dart';
import 'mobx_generator.dart';

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
    final result = StringBuffer();

    // Looks for @AnthemModel on each class in the file, and generates the
    // appropriate code
    for (final libraryClass in library.classes) {
      final annotationFromAnalyzer = const TypeChecker.typeNamed(
        AnthemModel,
        inPackage: 'anthem_codegen',
      ).firstAnnotationOf(libraryClass);

      // If there is no annotation on this class, don't do anything
      if (annotationFromAnalyzer == null) continue;

      // Read properties from @AnthemModel() annotation

      final context = ModelClassInfo(library, libraryClass);

      result.write(
        'mixin _\$${libraryClass.name}AnthemModelMixin on ${context.baseClass.name}${context.annotation!.generateModelSync ? ', AnthemModelBase' : ''} {\n',
      );

      if (context.annotation!.serializable) {
        result.write('\n  // JSON serialization\n');
        result.write('\n');
        result.write(generateJsonSerializationCode(context: context));
        result.write('\n  // JSON deserialization\n');
        result.write('\n');
        result.write(generateJsonDeserializationCode(context: context));
      }
      result.write('\n  // MobX atoms\n');
      result.write('\n');
      result.write(generateMobXAtoms(context: context));
      result.write('\n  // Getters and setters\n');
      result.write('\n');
      result.write(
        _generateGettersAndSetters(
          context: context,
          classHasModelSyncCode: context.annotation!.generateModelSync,
        ),
      );
      if (context.annotation!.generateModelSync) {
        result.write('\n  // Init function\n');
        result.write('\n');
        result.write(_generateInitFunction(context: context));

        result.write('\n  // onChange method\n');
        result.write(generateOnChangeMethod(context: context));
      }

      result.write('}\n');

      if (context.annotation!.generateModelSync) {
        result.write('\n');
        result.write(generateFilterBuilders(context: context));
      }
    }

    // The cache for parsed classes persists across files, so we need to clear
    // it for each file.
    cleanModelClassInfoCache();

    if (result.isEmpty) {
      return '';
    }

    const ignores = '// ignore_for_file: duplicate_ignore, unnecessary_overrides, non_constant_identifier_names\n';

    return ignores + result.toString();
  }
}

/// Generates getters and setters for model items.
///
/// Note that this will not generate anything for fields in sealed classes.
String _generateGettersAndSetters({
  required ModelClassInfo context,
  required bool classHasModelSyncCode,
}) {
  var result = StringBuffer();

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
            'Synced models must use AnthemObservableList, but $fieldName is using ${typeInfo.collectionType} instead.',
          );
        }
      }

      if (fieldInfo.typeInfo case MapModelType typeInfo) {
        if (typeInfo.collectionType != CollectionType.anthemObservable) {
          throw Exception(
            'Synced models must use AnthemObservableMap, but $fieldName is using ${typeInfo.collectionType} instead.',
          );
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
                'Synced models must use AnthemObservableList, but $fieldName is using ${subtype.collectionType} instead.',
              );
            }
          }

          if (subtype is MapModelType) {
            if (subtype.collectionType != CollectionType.anthemObservable) {
              throw Exception(
                'Synced models must use AnthemObservableMap, but $fieldName is using ${subtype.collectionType} instead.',
              );
            }
          }
        }
      }
    }

    // Getter

    final typeQ = fieldInfo.typeInfo.isNullable ? '?' : '';

    result.write('@override\n');
    result.write('${fieldInfo.typeInfo.dartName}$typeQ get $fieldName {\n');
    if (fieldInfo.isObservable) {
      result.write(generateMobXGetter(fieldName, fieldInfo));
    }
    result.write('return super.$fieldName;\n');
    result.write('}\n\n');

    // Setter

    var setter = StringBuffer();

    if (shouldGenerateModelSync) {
      setter.write('''
${fieldInfo.typeInfo.dartName}? \$oldValue;
try {
  \$oldValue = super.$fieldName;
}
catch (_) {
  \$oldValue = null;
}
''');
    }

    setter.write('super.$fieldName = \$value;\n');

    if (shouldGenerateModelSync) {
      // If the field is a custom model type, we need to tell it about its
      // parent.
      if (fieldInfo.typeInfo is CustomModelType ||
          fieldInfo.typeInfo is UnknownModelType ||
          fieldInfo.typeInfo is ListModelType ||
          fieldInfo.typeInfo is MapModelType) {
        final fieldGetter = 'super.$fieldName$typeQ';
        // If the model is not attached to its parent, then this will happen
        // to the entire subtree when it is attached. Otherwise, we need to
        // do it now.
        setter.write('''
if (isTopLevelModel || parent != null) {
  $fieldGetter.setParentProperties(
    parent: this,
    fieldName: '$fieldName',
    fieldType: FieldType.raw,
  );
}
''');
      } else if (fieldInfo.typeInfo case UnionModelType typeInfo) {
        var first = true;
        setter.write('''
var setterReceivedValidType = false;
''');
        for (final subtype in typeInfo.subTypes) {
          setter.write('''
${first ? '' : 'else '}if (\$value is ${subtype.dartName}) {
  setterReceivedValidType = true;
''');
          if (subtype is CustomModelType ||
              subtype is UnknownModelType ||
              subtype is ListModelType ||
              subtype is MapModelType) {
            // If the model is not attached to its parent, then this will happen
            // to the entire subtree when it is attached. Otherwise, we need to
            // do it now.
            setter.write('''
  if (isTopLevelModel || parent != null) {
    \$value.setParentProperties(
      parent: this,
      fieldName: '$fieldName',
      fieldType: FieldType.raw,
    );
  }
''');
          }
          setter.write('}');
          first = false;
        }

        setter.write('''if (!setterReceivedValidType) {
  throw Exception('Invalid type for field $fieldName. Got value of type \${\$value.runtimeType}, but expected one of: ${typeInfo.subTypes.map((subtype) => subtype.dartName).join(', ')}.');
}
''');
      }

      final valueGetter = createSerializerForField(
        type: fieldInfo.typeInfo,
        accessor: '\$value',
        alwaysIncludeEngineOnlyFields: true,
      );

      // Regardless of the type, we need to notify that this field was
      // changed.
      setter.write('''
notifyFieldChanged(
  operation: RawFieldUpdate(
    oldValue: \$oldValue,
    newValue: \$value,
    newValueSerialized: $valueGetter,
  ),
  accessorChain: [
    FieldAccessor(
      fieldType: FieldType.raw,
      fieldName: '$fieldName',
    ),
  ],
);
''');
    }

    result.write('@override\n');
    result.write(
      'set $fieldName(${fieldInfo.typeInfo.dartName}$typeQ \$value) {\n',
    );
    if (fieldInfo.isObservable) {
      result.write(
        wrapCodeWithMobXSetter(fieldName, fieldInfo, setter.toString()),
      );
    } else {
      result.write(setter);
    }

    result.write('}\n\n');
  }

  return result.toString();
}

/// Generates the init function for the model.
///
/// This should only be called if the model is a synced model.
String _generateInitFunction({required ModelClassInfo context}) {
  var result = StringBuffer();
  result.write('@override\n');

  result.write('void setParentPropertiesOnChildren() {\n');

  for (final MapEntry(key: fieldName, value: fieldInfo)
      in context.fields.entries) {
    final typeQ = fieldInfo.typeInfo.isNullable ? '?' : '';

    if (fieldInfo.typeInfo is ListModelType ||
        fieldInfo.typeInfo is MapModelType ||
        fieldInfo.typeInfo is CustomModelType) {
      final fieldGetter = 'super.$fieldName$typeQ';
      // If the model is not attached to its parent, then this will happen
      // to the entire subtree when it is attached. Otherwise, we need to
      // do it now.
      result.write('''
  $fieldGetter.setParentProperties(
    parent: this,
    fieldName: '$fieldName',
    fieldType: FieldType.raw,
  );
''');
    } else if (fieldInfo.typeInfo is UnionModelType) {
      var first = true;
      result.write('var setterReceivedValidType = false;\n');

      if (fieldInfo.typeInfo.isNullable) {
        result.write('''
if (super.$fieldName == null) {
  setterReceivedValidType = true;
}
''');
        first = false;
      }

      for (final subtype in (fieldInfo.typeInfo as UnionModelType).subTypes) {
        result.write('''
${first ? '' : 'else '}if (super.$fieldName is ${subtype.dartName}) {
  setterReceivedValidType = true;
''');
        if (subtype is CustomModelType ||
            subtype is UnknownModelType ||
            subtype is ListModelType ||
            subtype is MapModelType) {
          final fieldGetter = '(super.$fieldName as ${subtype.dartName})';
          // If the model is not attached to its parent, then this will happen
          // to the entire subtree when it is attached. Otherwise, we need to
          // do it now.
          result.write('''
  if (isTopLevelModel || parent != null) {
    $fieldGetter.setParentProperties(
      parent: this,
      fieldName: '$fieldName',
      fieldType: FieldType.raw,
    );
  }
''');
        }
        result.write('}\n');
        first = false;
      }

      result.write('''
if (!setterReceivedValidType) {
  throw Exception('Invalid type of initial value for union field "$fieldName". Got value of type \${super.$fieldName.runtimeType}, but expected one of: ${(fieldInfo.typeInfo as UnionModelType).subTypes.map((subtype) => subtype.dartName).join(', ')}.');
}
''');
    }
  }

  result.write('}\n');

  return result.toString();
}
