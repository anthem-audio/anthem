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

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'model_class_info.dart';

/// Represents a type in the model.
sealed class ModelType {
  abstract final bool canBeMapKey;
  abstract final String name;
  final bool isNullable;

  ModelType({required this.isNullable});
}

class StringModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get name => 'String';

  StringModelType({required super.isNullable});
}

class IntModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get name => 'int';

  IntModelType({required super.isNullable});
}

class DoubleModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get name => 'double';

  DoubleModelType({required super.isNullable});
}

class NumModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get name => 'num';

  NumModelType({required super.isNullable});
}

class BoolModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  @override
  String get name => 'bool';

  BoolModelType({required super.isNullable});
}

class EnumModelType extends ModelType {
  @override
  final bool canBeMapKey = true;

  final String enumName;

  final EnumElement enumElement;

  EnumModelType(this.enumName,
      {required super.isNullable, required this.enumElement});

  @override
  String get name => enumName;
}

class ListModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  /// Defines whether this is a regular list (false) or a MobX ObservableList
  /// (true).
  final bool isObservable;

  final ModelType itemType;

  ListModelType(this.itemType,
      {this.isObservable = false, required super.isNullable});

  @override
  String get name => 'List<${itemType.name}${itemType.isNullable ? '?' : ''}>';
}

class MapModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  /// Defines whether this is a regular map (false) or a MobX ObservableMap
  /// (true).
  final bool isObservable;

  final ModelType keyType;
  final ModelType valueType;

  MapModelType(this.keyType, this.valueType,
      {this.isObservable = false, required super.isNullable});

  @override
  String get name =>
      'Map<${keyType.name}${keyType.isNullable ? '?' : ''}, ${valueType.name}${valueType.isNullable ? '?' : ''}>';
}

/// Represents a custom type that is defined as an Anthem model
class CustomModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  final ModelClassInfo type;

  CustomModelType(this.type, {required super.isNullable});

  @override
  String get name => type.annotatedClass.name;
}

/// Represents a type that may or may not be valid, but cannot be parsed for
/// some reason.
class UnknownModelType extends ModelType {
  @override
  final bool canBeMapKey = false;

  @override
  String get name => 'void';

  UnknownModelType() : super(isNullable: false);
}

/// Parses a Dart type into a [ModelType].
ModelType getModelType(
    DartType type, LibraryReader libraryReader, ClassElement annotatedClass) {
  final element = type.element;
  if (element == null) return UnknownModelType();

  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  return switch (element.name) {
    'bool' => BoolModelType(isNullable: isNullable),
    'int' => IntModelType(isNullable: isNullable),
    'double' => DoubleModelType(isNullable: isNullable),
    'num' => NumModelType(isNullable: isNullable),
    'String' => StringModelType(isNullable: isNullable),
    _ => (() {
        // Check if this is a list
        if (element is ClassElement &&
            (element.name == 'List' || element.name == 'ObservableList')) {
          if (type is! ParameterizedType) return UnknownModelType();

          final typeParam = type.typeArguments.first;
          if (typeParam.element == null) return UnknownModelType();

          final itemType =
              getModelType(typeParam, libraryReader, annotatedClass);
          return ListModelType(
            itemType,
            isObservable: element.name == 'ObservableList',
            isNullable: isNullable,
          );
        }

        // Check if this is a map
        if (element is ClassElement &&
            (element.name == 'Map' || element.name == 'ObservableMap')) {
          if (type is! ParameterizedType) return UnknownModelType();

          final typeParams = type.typeArguments;
          if (typeParams.length != 2) return UnknownModelType();

          final keyType =
              getModelType(typeParams[0], libraryReader, annotatedClass);
          if (!keyType.canBeMapKey) {
            log.warning(
                'Map key type cannot be used as a map key: ${typeParams[0].element?.name}');
            return UnknownModelType();
          }

          final valueType =
              getModelType(typeParams[1], libraryReader, annotatedClass);
          return MapModelType(
            keyType,
            valueType,
            isObservable: element.name == 'ObservableMap',
            isNullable: isNullable,
          );
        }

        // Check for custom type
        else if (element is ClassElement) {
          try {
            final type = ModelClassInfo(libraryReader, element);
            return CustomModelType(type, isNullable: isNullable);
          } catch (e) {
            log.warning('Error parsing custom type: ${element.name}');
            log.warning(
                'This may be because the type is not annotated as an Anthem model, or is not formed correctly.');
            return UnknownModelType();
          }
        }

        // Check for enum
        else if (element is EnumElement) {
          return EnumModelType(element.name,
              isNullable: isNullable, enumElement: element);
        }

        log.warning(
            'Unknown type: ${element.name}. This is not expected, and may be a bug.');

        return UnknownModelType();
      })(),
  };
}
