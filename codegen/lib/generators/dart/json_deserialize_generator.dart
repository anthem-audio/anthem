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

import 'package:analyzer/dart/element/element.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';
import 'package:source_gen/source_gen.dart';

/// Generates code to deserialize JSON objects into model objects.
String generateJsonDeserializationCode({
  required ModelClassInfo context,
}) {
  var result = StringBuffer();

  result.write('''// ignore: duplicate_ignore
// ignore: non_constant_identifier_names
static ${context.annotatedClass.name} fromJson(Map<String, dynamic> json) {
''');

  // If the class is not sealed, we can just create an instance of the class
  if (!context.isSealed) {
    // If the class has a special uninitialized constructor, we use that. If
    // this constructor does not exist, then there must be a default constructor
    // with no arguments.
    if (context.annotatedClass.getNamedConstructor('uninitialized') != null) {
      result.write(
          'final result = ${context.annotatedClass.name}.uninitialized();\n');
    } else {
      result.write('final result = ${context.annotatedClass.name}();\n');
    }
  } else {
    result.write('late final ${context.annotatedClass.name} result;');

    bool isFirst = true;
    for (final subclass in context.sealedSubclasses) {
      result.write(
          '${isFirst ? '' : 'else '}if (json[\'__type\'] == \'${subclass.name}\') {\n');
      isFirst = false;

      // If the class has a special uninitialized constructor, we use that. If
      // this constructor does not exist, then there must be a default
      // constructor with no arguments.
      if (subclass.subclass.getNamedConstructor('uninitialized') != null) {
        result.write(
            'final subclassResult = ${subclass.name}.uninitialized();\n');
      } else {
        result.write('final subclassResult = ${subclass.name}();\n');
      }

      for (final entry in subclass.fields.entries) {
        final name = entry.key;
        final fieldInfo = entry.value;

        if (fieldInfo.isModelConstant) {
          continue;
        }

        if (_shouldSkip(fieldInfo.fieldElement)) {
          continue;
        }

        result.write(_createSetterForField(
          type: fieldInfo.typeInfo,
          fieldName: name,
          jsonName: 'json',
          resultName: 'subclassResult',
        ));
      }

      result.write('result = subclassResult;\n');
      result.write('}\n');
    }
  }

  for (final entry in context.fields.entries) {
    final name = entry.key;
    final fieldInfo = entry.value;

    if (fieldInfo.isModelConstant) {
      continue;
    }

    if (_shouldSkip(fieldInfo.fieldElement)) {
      continue;
    }

    result.write(_createSetterForField(
      type: fieldInfo.typeInfo,
      fieldName: name,
      jsonName: 'json',
      resultName: 'result',
    ));
  }

  result.write('''
  return result;
}
''');

  return result.toString();
}

/// Checks if a field should be skipped when generating JSON serialization code,
/// based on the @Hide annotation.
bool _shouldSkip(FieldElement field) {
  final hideAnnotation =
      const TypeChecker.fromRuntime(Hide).firstAnnotationOf(field);

  if (hideAnnotation == null) return false;

  final hide = Hide(
    serialization:
        hideAnnotation.getField('serialization')?.toBoolValue() ?? false,
  );

  return hide.serialization;
}

String _createSetterForField({
  required ModelType type,
  required String fieldName,
  required String jsonName,
  required String resultName,
}) {
  final rawGetter = '$jsonName[\'$fieldName\']';

  final convertedGetter = _createGetterForField(
    type: type,
    fieldName: fieldName,
    getter: rawGetter,
  );

  return '$resultName.$fieldName = $convertedGetter;';
}

String _createGetterForField({
  required ModelType type,
  required String fieldName,
  required String getter,
}) {
  final q = type.isNullable ? '?' : '';

  return switch (type) {
    StringModelType() => '$getter as String$q',
    IntModelType() => '$getter as int$q',
    DoubleModelType() => '$getter as double$q',
    NumModelType() => '$getter as num$q',
    BoolModelType() => '$getter as bool$q',
    ColorModelType() =>
      '''${type.isNullable ? '$getter == null ? null : ' : ''}Color.fromARGB(
  $getter['a'] as int,
  $getter['r'] as int,
  $getter['g'] as int,
  $getter['b'] as int,
)''',
    EnumModelType(enumName: var enumName) =>
      '${type.isNullable ? '$getter == null ? null : ' : ''}$enumName.values.firstWhere((e) => e.name == $getter)',
    ListModelType() => _generateListGetter(
        type: type,
        fieldName: fieldName,
        getter: getter,
      ),
    MapModelType() => _generateMapGetter(
        type: type,
        fieldName: fieldName,
        getter: getter,
      ),
    CustomModelType() =>
      '${type.isNullable ? '$getter == null ? null : ' : ''}${type.modelClassInfo.annotatedClass.name}.fromJson($getter)',
    UnionModelType() => _generateUnionGetter(
        type: type,
        fieldName: fieldName,
        getter: getter,
      ),
    UnknownModelType() => 'null',
  };
}

String _generateListGetter({
  required ListModelType type,
  required String fieldName,
  required String getter,
}) {
  final q = type.isNullable ? '?' : '';
  final listParameterTypeQ = type.itemType.isNullable ? '?' : '';

  final result = '''($getter as List$q)$q.map((e) {
  return ${_createGetterForField(type: type.itemType, fieldName: fieldName, getter: 'e')};
}).cast<${type.itemType.dartName}$listParameterTypeQ>().toList()''';

  switch (type.collectionType) {
    case CollectionType.raw:
      return result;
    case CollectionType.mobXObservable:
      return 'ObservableList.of($result)';
    case CollectionType.anthemObservable:
      return 'AnthemObservableList.of($result)';
  }
}

String _generateMapGetter({
  required MapModelType type,
  required String fieldName,
  required String getter,
}) {
  final q = type.isNullable ? '?' : '';
  final keyTypeQ = type.keyType.isNullable ? '?' : '';
  final valueTypeQ = type.valueType.isNullable ? '?' : '';

  final result = '''(() {
  final valueFromJson = $getter as Map<String, dynamic>$q;
  ${type.isNullable ? 'if (valueFromJson == null) return null;' : ''}

  final map = <${type.keyType.dartName}$keyTypeQ, ${type.valueType.dartName}$valueTypeQ>{};

  for (final entry in valueFromJson.entries) {
    map[${_createGetterForKeyField(type: type.keyType, fieldName: fieldName, getter: 'entry.key')}]
        = ${_createGetterForField(type: type.valueType, fieldName: fieldName, getter: 'entry.value')};
  }

  return map;
})()''';

  switch (type.collectionType) {
    case CollectionType.raw:
      return result;
    case CollectionType.mobXObservable:
      return 'ObservableMap.of($result)';
    case CollectionType.anthemObservable:
      return 'AnthemObservableMap.of($result)';
  }
}

String _createGetterForKeyField({
  required ModelType type,
  required String fieldName,
  required String getter,
}) {
  if (type.isNullable) {
    return switch (type) {
      StringModelType() =>
        throw Exception('String keys in maps cannot be nullable'),
      IntModelType() => "$getter == 'null' ? null : int.parse($getter)",
      DoubleModelType() => "$getter == 'null' ? null : double.parse($getter)",
      NumModelType() => "$getter == 'null' ? null : num.parse($getter)",
      BoolModelType() => "$getter == 'null' ? null : bool.parse($getter)",
      _ => 'null',
    };
  }

  return switch (type) {
    StringModelType() => getter,
    IntModelType() => 'int.parse($getter)',
    DoubleModelType() => 'double.parse($getter)',
    NumModelType() => 'num.parse($getter)',
    BoolModelType() => 'bool.parse($getter)',
    _ => 'null',
  };
}

String _generateUnionGetter({
  required UnionModelType type,
  required String fieldName,
  required String getter,
}) {
  return '''
(() {
  final keys = $getter${type.isNullable ? '?' : ''}.keys;

  ${type.isNullable ? 'if ($getter == null) return null;' : ''}

  if (keys.length != 1) {
    throw Exception('Union type must have exactly one key');
  }

  switch (keys.first) {
  ${type.subTypes.map((subtype) => '''
    case '${subtype.dartName}':
      return ${_createGetterForField(type: subtype, fieldName: fieldName, getter: '$getter[keys.first]')};
  ''').join('\n')}
    default:
      throw Exception('Unknown union type');
  }
})()
''';
}
