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

/// Generates JSON serialization and deserialization for an Anthem model class.
///
/// We use this over built-in serialization techniques because it allows us to
/// handle special cases more elegantly. Before, MobX observable collections
/// needed to have bespoke serializers and deserializers defined, which were
/// difficult to write and to read.
String generateJsonSerializationCode({
  required ModelClassInfo context,
}) {
  var result = '';

  // Generate serialization

  // TODO: Remove the ANTHEM tag
  result += '''// ignore: duplicate_ignore
// ignore: non_constant_identifier_names
Map<String, dynamic> toJson_ANTHEM() {
  final map = <String, dynamic>{};
''';

  for (final entry in context.fields.entries) {
    final name = entry.key;
    final field = entry.value;

    switch (field) {
      case StringModelType():
      case IntModelType():
      case DoubleModelType():
      case NumModelType():
      case BoolModelType():
        result += "map['$name'] = $name;\n";
        break;
      case ListModelType():
        result += '  // $name: list\n';
        break;
      case MapModelType():
        result += '  // $name: map\n';
        break;
      case CustomModelType():
        result += '  // $name: custom\n';
        break;
      case UnknownModelType():
        result += '  // $name: unknown\n';
        break;
    }
  }

  result += '''
  return map;
}
''';

  // Generate deserialization

  return result;
}
