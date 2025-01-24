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

import 'package:anthem_codegen/generators/util/model_types.dart';

import '../util/model_class_info.dart';

String getCppType(ModelType type, ModelClassInfo context) {
  final typeStr = switch (type) {
    StringModelType() => 'std::string',
    IntModelType() => 'int64_t',
    DoubleModelType() || NumModelType() => 'double',
    BoolModelType() => 'bool',
    ColorModelType() =>
      'rfl::NamedTuple<rfl::Field<"r", unsigned char>, rfl::Field<"g", unsigned char>, rfl::Field<"b", unsigned char>, rfl::Field<"a", unsigned char>>',
    EnumModelType(enumName: final name) => name,
    ListModelType(itemType: final inner) =>
      'std::shared_ptr<${context.annotation?.generateModelSync == true ? 'AnthemModelVector' : 'std::vector'}<${getCppType(inner, context)}>>',
    MapModelType(keyType: final key, valueType: final value) =>
      'std::shared_ptr<${context.annotation?.generateModelSync == true ? 'AnthemModelUnorderedMap' : 'std::unordered_map'}<${getCppType(key, context)}, ${getCppType(value, context)}>>',
    CustomModelType(dartName: final dartName) =>
      'std::shared_ptr<${type.modelClassInfo.annotation?.cppBehaviorClassName != null ? type.modelClassInfo.annotation!.cppBehaviorClassName : dartName}>',
    UnionModelType() =>
      'rfl::Variant<${type.subTypes.map((subType) => 'rfl::Field<"${subType.dartName}", ${getCppType(subType, context)}>').join(', ')}>',
    UnknownModelType() => 'TYPE_ERROR_UNKNOWN_TYPE',
  };

  if (type.isNullable) {
    return 'std::optional<$typeStr>';
  }

  return typeStr;
}
