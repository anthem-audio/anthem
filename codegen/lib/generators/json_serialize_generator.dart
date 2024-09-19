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

  if (context.isSealed) {
    // For sealed classes, we figure out which subclass we're dealing with and
    // use the name of that subclass to inform a field in the JSON map. This
    // allows us to determine the correct base class when deserializing.
    result += 'map[\'__type\'] = runtimeType.toString();\n';

    // Then, we output code to determine which fields to serialize depending on
    // the current subtype
    var isFirst = true;
    for (final subclass in context.sealedSubclasses) {
      if (isFirst) {
        result += 'if (this is ${subclass.name}) {\n';
        isFirst = false;
      } else {
        result += 'else if (this is ${subclass.name}) {\n';
      }

      for (final field in subclass.fields.entries) {
        final name = field.key;
        final type = field.value;

        result += _createSetterForField(
          type: type,
          fieldName: name,
          accessor: '(this as ${subclass.name}).$name',
          mapName: 'map',
        );
      }

      result += '}\n';
    }
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
  String? accessor,
  required String mapName,
}) {
  accessor ??= fieldName;

  final converter = _createConverterForField(
    type: type,
    accessor: accessor,
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

String _createConverterForField(
    {required ModelType type, required String accessor}) {
  return switch (type) {
    StringModelType() ||
    IntModelType() ||
    DoubleModelType() ||
    NumModelType() ||
    BoolModelType() =>
      _createConverterForPrimitive(accessor: accessor),
    EnumModelType(isNullable: var isNullable) =>
      _createConverterForEnum(accessor: accessor, isNullable: isNullable),
    ListModelType() => _createConverterForList(type: type, accessor: accessor),
    MapModelType() => _createConverterForMap(type: type, accessor: accessor),
    CustomModelType() =>
      _createConverterForCustomType(type: type, accessor: accessor),
    UnknownModelType() => 'null',
  };
}

String _createConverterForPrimitive({
  required String accessor,
}) {
  return accessor;
}

String _createConverterForEnum({
  required String accessor,
  required bool isNullable,
}) {
  return isNullable ? '$accessor?.name' : '$accessor.name';
}

String _createConverterForList({
  required ListModelType type,
  required String accessor,
}) {
  final q = type.isNullable ? '?' : '';

  return '''
$accessor$q.map(
  (item) {
    return ${_createConverterForField(type: type.itemType, accessor: 'item')};
  },
).toList()
''';
}

String _createConverterForMap({
  required MapModelType type,
  required String accessor,
}) {
  final nullablePrefix = type.isNullable ? '$accessor == null ? null : ' : '';
  final excl = type.isNullable ? '!' : '';

  return '''
${nullablePrefix}Map.fromEntries(
  $accessor$excl.entries.map(
    (entry) {
      return MapEntry(
        ${_createConverterForField(type: type.keyType, accessor: 'entry.key')}${type.keyType is StringModelType ? '' : '.toString()'},
        ${_createConverterForField(type: type.valueType, accessor: 'entry.value')},
      );
    },
  ),
)
''';
}

String _createConverterForCustomType({
  required CustomModelType type,
  required String accessor,
}) {
  return '$accessor${type.isNullable ? '?' : ''}.toJson_ANTHEM()';
}
