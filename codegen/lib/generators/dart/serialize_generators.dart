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

import '../util/model_types.dart';

String createSerializerForField({
  required ModelType type,
  required String accessor,
  bool alwaysIncludeEngineOnlyFields = false,
}) {
  return switch (type) {
    StringModelType() ||
    IntModelType() ||
    DoubleModelType() ||
    NumModelType() ||
    BoolModelType() =>
      createSerializerForPrimitive(accessor: accessor),
    ColorModelType() => createSerializerForColor(
        accessor: accessor,
      ),
    EnumModelType(isNullable: var isNullable) => createSerializerForEnum(
        accessor: accessor,
        isNullable: isNullable,
      ),
    ListModelType() => createSerializerForList(
        type: type,
        accessor: accessor,
        alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields,
      ),
    MapModelType() => createSerializerForMap(
        type: type,
        accessor: accessor,
        alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields,
      ),
    CustomModelType() => createSerializerForCustomType(
        type: type,
        accessor: accessor,
        alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields,
      ),
    UnionModelType() => createSerializerForUnion(
        type: type,
        accessor: accessor,
        alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields,
      ),
    UnknownModelType() => 'null',
  };
}

String createSerializerForPrimitive({
  required String accessor,
}) {
  return accessor;
}

/// Converts a Color object at [accessor] to a map of ARGB values.
///
/// Each value is stored as an integer between 0 and 255.
String createSerializerForColor({
  required String accessor,
}) {
  return '''
{'a': ($accessor.a * 255).round(), 'r': $accessor.r.round(), 'g': $accessor.g.round(), 'b': $accessor.b.round()}
''';
}

String createSerializerForEnum({
  required String accessor,
  required bool isNullable,
}) {
  return isNullable ? '$accessor?.name' : '$accessor.name';
}

String createSerializerForList({
  required ListModelType type,
  required String accessor,
  bool alwaysIncludeEngineOnlyFields = false,
}) {
  final q = type.isNullable ? '?' : '';
  final nonObservableInner = type.isObservable ? '.nonObservableInner' : '';

  return '''
$accessor$q$nonObservableInner.map(
  (item) {
    return ${createSerializerForField(type: type.itemType, accessor: 'item', alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields)};
  },
).toList()
''';
}

String createSerializerForMap({
  required MapModelType type,
  required String accessor,
  bool alwaysIncludeEngineOnlyFields = false,
}) {
  final nullablePrefix = type.isNullable ? '$accessor == null ? null : ' : '';
  final excl = type.isNullable ? '!' : '';
  final nonObservableInner = type.isObservable ? '.nonObservableInner' : '';

  return '''
${nullablePrefix}Map.fromEntries(
  $accessor$excl$nonObservableInner.entries.map(
    (entry) {
      return MapEntry(
        ${createSerializerForField(type: type.keyType, accessor: 'entry.key', alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields)}${type.keyType is StringModelType ? '' : '.toString()'},
        ${createSerializerForField(type: type.valueType, accessor: 'entry.value', alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields)},
      );
    },
  ),
)
''';
}

String createSerializerForCustomType({
  required CustomModelType type,
  required String accessor,
  bool alwaysIncludeEngineOnlyFields = false,
}) {
  // There are two cases for this:
  // 1. This serializer is being output in the context of a toJson method, in
  //    which case the parameter includeFieldsForEngine will be provided as an
  //    argument
  // 2. This serializer is being output in the context of a generated setter,
  //    and the serialized value is being sent to the engine as part of a model
  //    change event. In this case, there will be no includeFieldsForEngine
  //    parameter, and we need to include the engine-only fields.
  final includeFieldsForEngine =
      alwaysIncludeEngineOnlyFields ? 'true' : 'includeFieldsForEngine';
  return '$accessor${type.isNullable ? '?' : ''}.toJson(includeFieldsForEngine: $includeFieldsForEngine)';
}

String createSerializerForUnion({
  required UnionModelType type,
  required String accessor,
  bool alwaysIncludeEngineOnlyFields = false,
}) {
  var switchCases = '';

  for (final subtype in type.subTypes) {
    switchCases += '''
  case ${subtype.dartName} field:
    return {'${subtype.dartName}': ${createSerializerForField(type: subtype, accessor: 'field', alwaysIncludeEngineOnlyFields: alwaysIncludeEngineOnlyFields)}};
''';
  }

  return '''
(() {
  switch ($accessor) {
    $switchCases
  }
})()''';
}
