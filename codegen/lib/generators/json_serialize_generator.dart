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

import 'package:anthem_codegen/generators/util/model_types.dart';

import 'util/model_class_info.dart';

/// Generates JSON serialization for an Anthem model class.
///
/// We use this over built-in serialization techniques because it allows us to
/// handle special cases more elegantly. Before, MobX observable collections
/// needed to have bespoke serializers and deserializers defined, which were
/// difficult to write and to read.
String generateJsonSerializationCode({
  required ModelClassInfo context,
}) {
  var result = '';

  // TODO: Remove the ANTHEM tag
  result += '''// ignore: duplicate_ignore
// ignore: non_constant_identifier_names
Map<String, dynamic> toJson_ANTHEM() {
  final map = <String, dynamic>{};
''';

  for (final entry in context.fields.entries) {
    final name = entry.key;
    final field = entry.value;

    result += _createSetterForField(
      type: field,
      fieldName: name,
      mapName: 'map',
    );
  }

  result += '''
  return map;
}
''';

  // Generate deserialization

  return result;
}

String _createSetterForField({
  required ModelType type,
  required String fieldName,
  required String mapName,
}) {
  final converter = _createConverterForField(
    type: type,
    fieldName: fieldName,
  );

  // If the field is nullable, we need to check if the value we're adding to the
  // JSON map is null before adding it
  if (type.isNullable) {
    return '''{
    final value = $converter;
    if (value != null) {
      $mapName['$fieldName'] = value;
    }
  }
''';
  }

  return "$mapName['$fieldName'] = $converter;\n";
}

String _createConverterForField({
  required ModelType type,
  required String fieldName,
}) {
  return switch (type) {
    StringModelType() ||
    IntModelType() ||
    DoubleModelType() ||
    NumModelType() ||
    BoolModelType() =>
      _createConverterForPrimitive(fieldName: fieldName),
    EnumModelType(isNullable: var isNullable) =>
      _createConverterForEnum(fieldName: fieldName, isNullable: isNullable),
    ListModelType(isNullable: var isNullable) => _createConverterForList(
        type: type, fieldName: fieldName, isNullable: isNullable),
    MapModelType(isNullable: var isNullable) => _createConverterForMap(
        type: type, fieldName: fieldName, isNullable: isNullable),
    CustomModelType(isNullable: var isNullable) =>
      _createConverterForCustomType(
          type: type, fieldName: fieldName, isNullable: isNullable),
    UnknownModelType() => 'null',
  };
}

String _createConverterForPrimitive({
  required String fieldName,
}) {
  return fieldName;
}

String _createConverterForEnum({
  required String fieldName,
  required bool isNullable,
}) {
  return isNullable ? '$fieldName?.name' : '$fieldName.name';
}

String _createConverterForList({
  required ListModelType type,
  required String fieldName,
  required bool isNullable,
}) {
  final q = isNullable ? '?' : '';

  return '''
$fieldName$q.map(
  (item) {
    return ${_createConverterForField(type: type.itemType, fieldName: 'item')};
  },
).toList()
''';
}

String _createConverterForMap({
  required MapModelType type,
  required String fieldName,
  required bool isNullable,
}) {
  final nullablePrefix = isNullable ? '$fieldName == null ? null : ' : '';
  final excl = isNullable ? '!' : '';

  return '''
${nullablePrefix}Map.fromEntries(
  $fieldName$excl.entries.map(
    (entry) {
      return MapEntry(
        ${_createConverterForField(type: type.keyType, fieldName: 'entry.key')}${type.keyType is StringModelType ? '' : '.toString()'},
        ${_createConverterForField(type: type.valueType, fieldName: 'entry.value')},
      );
    },
  ),
)
''';
}

String _createConverterForCustomType({
  required CustomModelType type,
  required String fieldName,
  required bool isNullable,
}) {
  return '$fieldName${isNullable ? '?' : ''}.toJson_ANTHEM()';
}
