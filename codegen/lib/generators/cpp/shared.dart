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

String getCppType(ModelType type) {
  final typeStr = switch (type) {
    StringModelType() => 'std::string',
    IntModelType() => 'int64_t',
    DoubleModelType() || NumModelType() => 'double',
    BoolModelType() => 'bool',
    ColorModelType() =>
      'rfl::NamedTuple<rfl::Field<"r", unsigned char>, rfl::Field<"g", unsigned char>, rfl::Field<"b", unsigned char>, rfl::Field<"a", unsigned char>>',
    EnumModelType(enumName: var name) => name,
    ListModelType(itemType: var inner) => 'std::vector<${getCppType(inner)}>',
    MapModelType(keyType: var key, valueType: var value) =>
      'std::map<${getCppType(key)}, ${getCppType(value)}>',
    CustomModelType(name: var name) => 'rfl::Ref<$name>',
    UnknownModelType() => 'TYPE_ERROR_UNKNOWN_TYPE',
  };

  if (type.isNullable) {
    return 'std::optional<$typeStr>';
  }

  return typeStr;
}
