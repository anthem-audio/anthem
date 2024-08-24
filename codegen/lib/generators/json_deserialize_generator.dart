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

import 'package:anthem_codegen/generators/util/model_class_info.dart';
import 'package:anthem_codegen/generators/util/model_types.dart';

/// Generates code to deserialize JSON objects into model objects.
String generateJsonDeserializationCode({
  required ModelClassInfo context,
}) {
  var result = '';

  // TODO: Remove the ANTHEM tag
  result += '''// ignore: duplicate_ignore
// ignore: non_constant_identifier_names
static ${context.annotatedClass.name} fromJson_ANTHEM(Map<String, dynamic> json) {
  final result = ${context.annotatedClass.name}();
''';

  for (final entry in context.fields.entries) {
    final name = entry.key;
    final field = entry.value;

    result += _createSetterForField(
      type: field,
      fieldName: name,
      jsonName: 'json',
      resultName: 'result',
    );
  }

  result += '''
  return result;
}
''';

  return result;
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
  return switch (type) {
    StringModelType() => '$getter as String',
    IntModelType() => '$getter as int',
    DoubleModelType() => '$getter as double',
    NumModelType() => '$getter as num',
    BoolModelType() => '$getter as bool',
    EnumModelType(enumName: var enumName) =>
      '$enumName.values.firstWhere((e) => e.name == $getter)',
    ListModelType(itemType: var itemType) => _generateListGetter(
        listParameterType: itemType,
        fieldName: fieldName,
        getter: getter,
      ),
    MapModelType(keyType: var keyType, valueType: var valueType) =>
      _generateMapGetter(
        keyType: keyType,
        valueType: valueType,
        fieldName: fieldName,
        getter: getter,
      ),
    CustomModelType() =>
      '${type.type.annotatedClass.name}.fromJson_ANTHEM($getter)',
    UnknownModelType() => 'null',
  };
}

String _generateListGetter({
  required ModelType listParameterType,
  required String fieldName,
  required String getter,
}) {
  return '''($getter as List).map((e) {
  return ${_createGetterForField(type: listParameterType, fieldName: fieldName, getter: 'e')};
}).cast<${listParameterType.name}>().toList()''';
}

String _generateMapGetter({
  required ModelType keyType,
  required ModelType valueType,
  required String fieldName,
  required String getter,
}) {
  return '''$getter.map((k, v) {
  return MapEntry(
    ${_createGetterForKeyField(type: keyType, fieldName: fieldName, getter: 'k')},
    ${_createGetterForField(type: valueType, fieldName: fieldName, getter: 'v')},
  );
}).cast<${keyType.name}, ${valueType.name}>()''';
}

String _createGetterForKeyField({
  required ModelType type,
  required String fieldName,
  required String getter,
}) {
  return switch (type) {
    StringModelType() => getter,
    IntModelType() => 'int.parse($getter)',
    DoubleModelType() => 'double.parse($getter)',
    NumModelType() => 'num.parse($getter)',
    BoolModelType() => 'bool.parse($getter)',
    _ => 'null',
  };
}
