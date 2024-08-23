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

import 'package:analyzer/dart/element/type.dart';

import 'model_class_info.dart';

/// Represents a type in the model.
sealed class ModelType {
  abstract final bool canBeMapKey;
}

class StringModelType extends ModelType {
  @override
  final bool canBeMapKey = true;
}

class IntModelType extends ModelType {
  @override
  final bool canBeMapKey = true;
}

class DoubleModelType extends ModelType {
  @override
  final bool canBeMapKey = true;
}

class NumModelType extends ModelType {
  @override
  final bool canBeMapKey = true;
}

class BoolModelType extends ModelType {
  @override
  final bool canBeMapKey = true;
}

class ListModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  /// Defines whether this is a regular list (false) or a MobX ObservableList
  /// (true).
  final bool isObservable;

  final ModelType itemType;

  ListModelType(this.itemType, {this.isObservable = false});
}

class MapModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  /// Defines whether this is a regular map (false) or a MobX ObservableMap
  /// (true).
  final bool isObservable;

  final ModelType keyType;
  final ModelType valueType;

  MapModelType(this.keyType, this.valueType, {this.isObservable = false});
}

/// Represents a custom type that is defined as an Anthem model
class CustomModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  final ModelClassInfo type;

  CustomModelType(this.type);
}

/// Represents a type that may or may not be valid, but cannot be parsed for
/// some reason.
class UnknownModelType extends ModelType {
  @override
  final bool canBeMapKey = false;
}

/// Parses a Dart type into a [ModelType].
ModelType getModelType(DartType type) {
  final element = type.element;
  if (element == null) return UnknownModelType();

  return switch (element.name) {
    'bool' => BoolModelType(),
    'int' => IntModelType(),
    'double' => DoubleModelType(),
    'num' => NumModelType(),
    _ => UnknownModelType(),
  };
}
